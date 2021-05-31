#!/usr/bin/env bash

PODMAN='sudo /usr/bin/podman'

PODNAME='malan_pod'

#PG_IMG='postgres:11.7-alpine'
#PG_IMG='postgres:12.6-alpine'
PG_NAME='malan_postgres'

#BODYHACK_IMG='freedomben/malan-dev'
BODYHACK_NAME='malan'

#MAX_CONNECTIONS=200

die () 
{
  echo "[DIE]: $1" >&2
  exit 1
}

delete_pod ()
{
  $PODMAN pod rm -f "$PODNAME"
}

stop_postgres ()
{
  $PODMAN stop $PG_NAME
  $PODMAN rm $PG_NAME
}

stop_malan ()
{
  $PODMAN stop "$BODYHACK_NAME"
  $PODMAN rm "$BODYHACK_NAME"
}

# Clean up old stuff
stop_malan
stop_postgres
delete_pod

