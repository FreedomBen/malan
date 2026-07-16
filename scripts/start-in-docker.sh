#!/usr/bin/env bash

set -e

echo "[*] Starting Malan as '${HOST}:${PORT}'"
echo "[-]   Host:Port '${HOST}:${PORT}'"
echo "[-]   Bound to ${BIND_ADDR}"

# Wait for Postgres to initialize
echo "[*] Waiting for PostgreSQL to initialize..."

# Prefer the CNPG contract variables (malan-pg-secrets in k8s); DB_HOSTNAME is
# the legacy/docker-compose fallback.
DB_WAIT_HOST="${POSTGRES_HOST:-${DB_HOSTNAME}}"
DB_WAIT_PORT="${POSTGRES_PORT:-5432}"
if [[ -z "${DB_WAIT_HOST}" ]]; then
  echo "[!] Neither POSTGRES_HOST nor DB_HOSTNAME is set; cannot wait for PostgreSQL."
  exit 1
fi
while ! ncat -z "${DB_WAIT_HOST}" "${DB_WAIT_PORT}"; do
  sleep 0.1
done

echo "[*] PostgreSQL responded"

if [[ "${DB_INIT}" =~ [yY] ]]; then
  echo "[*] DB_INIT is set to '${DB_INIT}'.  Creating DB (if necessary) and running any migrations..."

  if [[ "${MIX_ENV}" != "dev" && "${MIX_ENV}" != "test" ]]; then
    if [[ -z "${MALAN_ROOT_PASSWORD}" && -z "${MALAN_ROOT_PASSWORD_FILE}" ]]; then
      echo "[!] DB_INIT requested in MIX_ENV='${MIX_ENV}' but neither MALAN_ROOT_PASSWORD nor MALAN_ROOT_PASSWORD_FILE is set."
      echo "[!] Refusing to seed a root admin without an explicit password."
      exit 1
    fi
  fi

  mix ecto.setup

  echo "[*] Migrations finished successfully"
fi

echo "[*] Starting Phoenix server"
mix phx.server

