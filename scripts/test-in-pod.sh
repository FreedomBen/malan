#!/usr/bin/env bash

PODMAN='podman'

PODNAME='malan_pod'

PG_IMG='postgres:12.6-alpine'
#PG_IMG='postgres:11.7-alpine'
PG_NAME='malan_postgres'

MAX_CONNECTIONS=200

die () 
{
  echo "[DIE]: $1" >&2
  exit 1
}

create_pod ()
{
  echo "Creating pod..."
  $PODMAN pod create \
    --name "$PODNAME" \
    -p 4000:4000 \
    -p 5432:5432
  echo "Done creating pod"
}

# clean up old container if it's laying around - Finish
if sudo podman ps -a --format "{{.Names}} {{.Status}}" | grep -E "${PG_NAME}.Created" >/dev/null 2>&1; then
  sudo podman rm "${PG_NAME}"
fi

#if [ "$1" = 'test' ]; then
if [ "$1" = '-d' ]; then
  RM_OR_D='-d'
else
  RM_OR_D='--rm'
fi

sudo podman run \
  --interactive \
  --tty \
  --publish '5432:5432' \
  --user "$(id -u):$(id -g)" \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=password \
  --name "$PG_NAME" \
  $PG_IMG \
  -c "max_connections=${MAX_CONNECTIONS}"

if [ "$RM_OR_D" = '--rm' ]; then
  # cleanup pg_passwd if the container was run in the foreground
  rm -f pg_passwd
fi
