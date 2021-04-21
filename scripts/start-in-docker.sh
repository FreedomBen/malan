#!/usr/bin/env bash

set -e

# Wait for Postgres to initialize
echo "[*] Waiting for PostgreSQL to initialize..."

while ! nc -z db 5432; do
  sleep 0.1
done

echo "[*] PostgreSQL responded"

if [[ "$INIT_DB" =~ [yY] ]]; then
  echo "[*] INIT_DB is set to '$INIT_DB'.  Creating DB (if necessary) and running any migrations..."
  mix ecto.setup

  echo "[*] Migrations finished successfully"
fi

echo "[*] Starting Phoenix server"
mix phx.server
