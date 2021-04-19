#!/usr/bin/env bash

NAME='malan_postgres'

sudo podman exec \
  --interactive \
  "$NAME" \
  psql -U postgres -d "$1" < "$2"
