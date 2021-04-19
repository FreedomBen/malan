#!/usr/bin/env bash

PODMAN='sudo /usr/bin/podman'

PODNAME='malan_pod'

#PG_IMG='postgres:11.7-alpine'
PG_IMG='postgres:12.5-alpine'
PG_NAME='malan_postgres'

BODYHACK_IMG='freedomben/malan'
BODYHACK_NAME='malan'

MAX_CONNECTIONS=200

die () 
{
  echo "[DIE]: $1" >&2
  exit 1
}

delete_pod ()
{
  $PODMAN pod rm -f "$PODNAME"
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

stop_postgres ()
{
  $PODMAN stop $PG_NAME
  $PODMAN rm $PG_NAME
}

start_postgres ()
{
  $PODMAN run \
    --pod "$PODNAME" \
    --detach \
    --env POSTGRES_USER=postgres \
    --env POSTGRES_PASSWORD=password \
    --name "$PG_NAME" \
    $PG_IMG \
    -c "max_connections=${MAX_CONNECTIONS}"
}

stop_malan ()
{
  $PODMAN stop "$BODYHACK_NAME"
  $PODMAN rm "$BODYHACK_NAME"
}

run_malan ()
{
  $PODMAN run \
    --pod "$PODNAME" \
    --rm \
    --env POSTGRES_USER=postgres \
    --env POSTGRES_PASSWORD=password \
    --name "$BODYHACK_NAME" \
    $BODYHACK_IMG $@
}

start_malan ()
{
  $PODMAN run \
    --pod "$PODNAME" \
    --detach \
    --env POSTGRES_USER=postgres \
    --env POSTGRES_PASSWORD=password \
    --name "$BODYHACK_NAME" \
    $BODYHACK_IMG
}

# Clean up old stuff
stop_malan
stop_postgres
delete_pod

# Start new stuff
create_pod
start_postgres
echo "Sleeping 3 seconds to give Postgres time to start"
sleep 3
run_malan "mix ecto.create"
run_malan "mix ecto.migrate"
run_malan "mix run priv/repo/seeds.exs"
start_malan

