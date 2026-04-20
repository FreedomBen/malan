#!/usr/bin/env bash
#
# Reclaims space from the bloated `logs` table without downtime using
# pg_repack. Writes to `logs` continue during the rebuild; pg_repack
# only takes a brief ACCESS EXCLUSIVE lock at the very end to swap
# the heap.
#
# Context: The archiver moves rows older than 60 days out of `logs`,
# but autovacuum has not kept up with the dead-tuple churn. At the
# time this script was written the prod table held ~909K live rows in
# ~34 GB of heap (expected ~3-4 GB) plus ~3.9 GB of indexes. Staging
# went 446 MB -> 7 MB.
#
# Do NOT fall back to VACUUM FULL. It takes an ACCESS EXCLUSIVE lock
# for the full rebuild (tens of minutes at prod size), which blocks
# every log-writing endpoint. If pg_repack is not available, this
# script exits — fix the availability and re-run.
#
# ---------------------------------------------------------------------
# DigitalOcean managed PG gotchas (learned running this against staging)
# ---------------------------------------------------------------------
# 1. The app role (e.g. `malan`) cannot run pg_repack — it has no USAGE
#    on the `repack` schema. Connect as `doadmin`:
#      export DATABASE_URL="$(doctl databases connection <db-id> \
#          --format URI --no-header | sed 's|/defaultdb?|/<real_db>?|')"
# 2. `doadmin` is not a true superuser on managed PG. pg_repack is run
#    with `--no-superuser-check` to bypass the check.
# 3. DO ships pg_repack extension 1.5.0 only. The PGDG apt client is
#    1.5.3, which aborts with a version-mismatch error. The client
#    MUST match the extension major+minor. If the packaged client
#    doesn't match, build from source — see `build-pg-repack-client`
#    below.
# 4. pg_repack 1.5.0 does not parse libpq URIs passed to --dbname. We
#    break the URL out into -h/-p/-U/-d and pass the password via
#    PGPASSWORD env.
# 5. `--jobs=2` produced silent "Error with create index:" against DO
#    managed PG. `--jobs=1` worked. Default here is 1.
#
# Usage:
#   ./scripts/repack-logs-prod.sh           # dry run, prints the plan
#   ./scripts/repack-logs-prod.sh --execute # actually run the repack
#
# Env:
#   DATABASE_URL   Required. Must be a doadmin connection string
#                  (or any role with USAGE on the `repack` schema).
#   JOBS           Parallel index builds (default: 1 — see gotcha #5).
#   TABLE          Target table (default: public.logs).

set -euo pipefail

EXECUTE=0
if [[ "${1:-}" == "--execute" ]]; then
  EXECUTE=1
fi

: "${DATABASE_URL:?Set DATABASE_URL to the doadmin connection string}"
JOBS="${JOBS:-1}"
TABLE="${TABLE:-public.logs}"

# Normalize Elixir-style URLs (`ecto://`, bare `?ssl`) to libpq form.
DATABASE_URL="${DATABASE_URL/#ecto:\/\//postgresql:\/\/}"
DATABASE_URL="${DATABASE_URL//\?ssl=true/?sslmode=require}"
DATABASE_URL="${DATABASE_URL//\?ssl&/?sslmode=require&}"
DATABASE_URL="${DATABASE_URL/%\?ssl/?sslmode=require}"

# Split the URL into libpq env vars. pg_repack 1.5.0's --dbname does
# not parse URIs; individual flags + env are the reliable path.
_rest="${DATABASE_URL#*://}"
_creds="${_rest%%@*}"
_hostpart="${_rest#*@}"
_hostport="${_hostpart%%/*}"
_dbandq="${_hostpart#*/}"
export PGUSER="${_creds%%:*}"
export PGPASSWORD="${_creds#*:}"
export PGHOST="${_hostport%%:*}"
export PGPORT="${_hostport#*:}"
export PGDATABASE="${_dbandq%%\?*}"
export PGSSLMODE="${PGSSLMODE:-require}"
unset _rest _creds _hostpart _hostport _dbandq

echo "=== Target ==="
echo "host:     ${PGHOST}"
echo "port:     ${PGPORT}"
echo "database: ${PGDATABASE}"
echo "user:     ${PGUSER}"
echo "table:    ${TABLE}"
echo "jobs:     ${JOBS}"

if ! command -v pg_repack >/dev/null 2>&1; then
  cat <<EOF
ERROR: pg_repack client not found in PATH.

Install a client that matches the extension version exactly. On
DigitalOcean managed PG the extension is pinned to 1.5.0, and PGDG
apt/dnf ships 1.5.3 (mismatch — will fail). Build 1.5.0 from source:

  apt-get install -y build-essential libpq-dev postgresql-server-dev-16 \\
                     libzstd-dev liblz4-dev zlib1g-dev libreadline-dev git
  git clone --depth 1 --branch ver_1.5.0 https://github.com/reorg/pg_repack.git
  cd pg_repack && make
  export PATH="\$PWD/bin:\$PATH"
EOF
  exit 1
fi

client_ver="$(pg_repack --version 2>&1 | awk '{print $2}')"
echo "pg_repack client: ${client_ver}"

echo
echo "=== Pre-flight checks ==="
ext_ver="$(psql -At -c "SELECT extversion FROM pg_extension WHERE extname = 'pg_repack';")"
if [[ -z "${ext_ver}" ]]; then
  cat <<EOF
ERROR: pg_repack extension is not installed in ${PGDATABASE}.

Run as doadmin: CREATE EXTENSION pg_repack;
(Or deploy migration priv/repo/migrations/20260420200000_enable_pg_repack.exs
and wait for the next migration run.)
EOF
  exit 1
fi
echo "pg_repack extension: ${ext_ver}"

if [[ "${client_ver}" != "${ext_ver}" ]]; then
  cat <<EOF
ERROR: pg_repack client/extension version mismatch.
  client:    ${client_ver}
  extension: ${ext_ver}
pg_repack requires an exact match. Rebuild the client from the
matching tag (see the install hint printed earlier).
EOF
  exit 1
fi

echo
echo "=== Current size (${TABLE}) ==="
psql -c "
  SELECT
    pg_size_pretty(pg_table_size('${TABLE}'))          AS table_size,
    pg_size_pretty(pg_indexes_size('${TABLE}'))        AS index_size,
    pg_size_pretty(pg_total_relation_size('${TABLE}')) AS total_size,
    (SELECT n_live_tup FROM pg_stat_user_tables
       WHERE schemaname||'.'||relname = '${TABLE}')     AS live_tup,
    (SELECT n_dead_tup FROM pg_stat_user_tables
       WHERE schemaname||'.'||relname = '${TABLE}')     AS dead_tup;
"

CMD=(
  pg_repack
  -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}"
  --table="${TABLE}"
  --jobs="${JOBS}"
  --wait-timeout=60
  --no-superuser-check
)

if [[ "${EXECUTE}" -eq 0 ]]; then
  echo
  echo "=== DRY RUN ==="
  echo "Would execute (PGPASSWORD passed via env, not shown):"
  printf '  %q ' "${CMD[@]}"; echo
  echo
  echo "Re-run with --execute to perform the repack."
  echo
  echo "Notes:"
  echo "  * pg_repack needs roughly 2x the current table size in free disk."
  echo "  * Writes continue during the rebuild; a brief ACCESS EXCLUSIVE"
  echo "    lock is taken at the very end to swap the heap."
  echo "  * Drop unused indexes BEFORE this runs so pg_repack does not"
  echo "    rebuild them (migration 20260420190000_drop_unused_logs_indexes)."
  exit 0
fi

echo
echo "=== Running pg_repack on ${TABLE} ==="
date
"${CMD[@]}"
date

echo
echo "=== Post-repack size (${TABLE}) ==="
psql -c "
  SELECT
    pg_size_pretty(pg_table_size('${TABLE}'))          AS table_size,
    pg_size_pretty(pg_indexes_size('${TABLE}'))        AS index_size,
    pg_size_pretty(pg_total_relation_size('${TABLE}')) AS total_size;
"
echo "Done."
