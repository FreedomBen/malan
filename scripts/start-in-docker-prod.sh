#!/usr/bin/env bash
#
# Production release start script. Used as the CMD in the runtime stage
# of Dockerfile.prod. Mirrors scripts/start-in-docker.sh (which is for
# the dev Dockerfile) but invokes the assembled mix release
# (bin/malan eval / bin/malan start) instead of `mix`, since `mix` is
# not present in the release image.

set -e

HOST="${HOST:-localhost}"
PORT="${PORT:-4000}"
BIND_ADDR="${BIND_ADDR:-0.0.0.0}"
export HOST PORT BIND_ADDR

echo "[*] Starting Malan release as '${HOST}:${PORT}'"
echo "[-]   Host:Port '${HOST}:${PORT}'"
echo "[-]   Bound to ${BIND_ADDR}"

echo "[*] Waiting for PostgreSQL to initialize..."
while ! ncat -z "${DB_HOSTNAME}" 5432; do
  sleep 0.1
done
echo "[*] PostgreSQL responded"

if [[ "${DB_INIT}" =~ [yY] ]]; then
  echo "[*] DB_INIT='${DB_INIT}': running storage_up + migrations + seed..."

  if [[ -z "${MALAN_ROOT_PASSWORD}" && -z "${MALAN_ROOT_PASSWORD_FILE}" ]]; then
    echo "[!] DB_INIT requested but neither MALAN_ROOT_PASSWORD nor MALAN_ROOT_PASSWORD_FILE is set."
    echo "[!] Refusing to seed a root admin without an explicit password."
    exit 1
  fi

  /app/bin/malan eval "Malan.Release.setup()"
  echo "[*] Setup finished successfully"
fi

echo "[*] Starting Phoenix server"
exec /app/bin/malan start
