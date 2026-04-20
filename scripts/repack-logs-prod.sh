#!/usr/bin/env bash
#
# Reclaims space from the bloated `logs` table in prod without downtime.
#
# Context: The archiver moves rows older than 60 days out of `logs`, but
# autovacuum has not kept up with the dead-tuple churn. At the time this
# script was written the table held ~909K live rows in ~34 GB of heap
# (expected size ~3-4 GB) plus ~3.9 GB of indexes.
#
# Uses pg_repack so writes can continue against `logs` during the rebuild.
# pg_repack needs:
#   - the pg_repack extension installed in the target database
#   - a primary key on the table (logs has transactions_pkey)
#   - the pg_repack client binary available locally (dnf/apt: pg_repack or
#     postgresql-<ver>-repack)
#
# Do NOT fall back to VACUUM FULL. It takes an ACCESS EXCLUSIVE lock
# on `logs` for the full rebuild — tens of minutes at this size —
# which blocks every log-writing endpoint. If pg_repack is not
# available, this script exits; fix the underlying availability
# (install extension / install client) and re-run.
#
# Usage:
#   ./scripts/repack-logs-prod.sh           # dry run, prints the plan
#   ./scripts/repack-logs-prod.sh --execute # actually runs the repack
#
# Env:
#   DATABASE_URL   Required. Connection string for the prod DB.
#   JOBS           Parallel index builds (default: 2).

set -euo pipefail

EXECUTE=0
if [[ "${1:-}" == "--execute" ]]; then
  EXECUTE=1
fi

: "${DATABASE_URL:?Set DATABASE_URL to the prod connection string}"
JOBS="${JOBS:-2}"

if ! command -v pg_repack >/dev/null 2>&1; then
  echo "ERROR: pg_repack client not found in PATH."
  echo "Install it (Fedora: 'dnf install pg_repack', Ubuntu:"
  echo "'apt install postgresql-<version>-repack') or run from a host"
  echo "that has it, then re-run this script."
  exit 1
fi

echo "=== Pre-flight checks ==="
psql "${DATABASE_URL}" -At -c "SELECT extname FROM pg_extension WHERE extname = 'pg_repack';" \
  | grep -q pg_repack || {
    echo "pg_repack extension is not installed in the target database."
    echo "Run: CREATE EXTENSION pg_repack;"
    echo "(On DigitalOcean managed PG, enable it from the console or"
    echo "request via CLI: doctl databases sql <id> -- 'CREATE EXTENSION pg_repack')"
    exit 1
  }

echo "pg_repack extension: OK"

echo "=== Current size ==="
psql "${DATABASE_URL}" -c "
  SELECT
    pg_size_pretty(pg_table_size('logs'))    AS table_size,
    pg_size_pretty(pg_indexes_size('logs'))  AS index_size,
    pg_size_pretty(pg_total_relation_size('logs')) AS total_size,
    (SELECT n_live_tup FROM pg_stat_user_tables WHERE relname = 'logs') AS live_tup,
    (SELECT n_dead_tup FROM pg_stat_user_tables WHERE relname = 'logs') AS dead_tup;
"

CMD=(pg_repack --dbname="${DATABASE_URL}" --table=public.logs --jobs="${JOBS}" --wait-timeout=60)

if [[ "${EXECUTE}" -eq 0 ]]; then
  echo
  echo "=== DRY RUN ==="
  echo "Would execute:"
  printf '  %q ' "${CMD[@]}"; echo
  echo
  echo "Re-run with --execute to perform the repack."
  echo
  echo "Notes:"
  echo "  * pg_repack needs roughly 2x the current table size in free disk."
  echo "  * Writes to logs continue during the rebuild; a brief exclusive"
  echo "    lock is taken at the very end to swap the heap."
  echo "  * Run 'DROP INDEX CONCURRENTLY' on unused indexes BEFORE this"
  echo "    repack so pg_repack does not rebuild them (see migration"
  echo "    20260420_drop_unused_logs_indexes.exs)."
  exit 0
fi

echo
echo "=== Running pg_repack on public.logs ==="
date
"${CMD[@]}"
date

echo
echo "=== Post-repack size ==="
psql "${DATABASE_URL}" -c "
  SELECT
    pg_size_pretty(pg_table_size('logs'))    AS table_size,
    pg_size_pretty(pg_indexes_size('logs'))  AS index_size,
    pg_size_pretty(pg_total_relation_size('logs')) AS total_size;
"
echo "Done."
