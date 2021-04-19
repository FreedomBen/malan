#!/usr/bin/env bash

set -e

NAME='malan_postgres'

echo 'Dumping postgres schema to sql/schema.sql'

sudo podman exec \
  --interactive \
  --tty \
  "$NAME" \
  pg_dump -U postgres -s > sql/schema.sql

echo 'Dumping complete'
