#!/usr/bin/env bash

PODMAN='sudo /usr/bin/podman'
BODYHACK_NAME='malan'

die () 
{
  echo "[DIE]: $1" >&2
  exit 1
}

$PODMAN logs -f "$BODYHACK_NAME"
