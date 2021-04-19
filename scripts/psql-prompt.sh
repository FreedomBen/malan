#!/usr/bin/env bash

NAME='malan_postgres'

sudo podman exec \
  --interactive \
  --tty \
  "$NAME" \
  psql -U postgres
