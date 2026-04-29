#!/usr/bin/env bash

# Starts a local Redis container for development/test. Mirrors the style
# of scripts/start-postgres.sh so the dev workflow (start-postgres.sh +
# start-redis.sh + mix phx.server) is consistent.
#
# Malan.RateLimiter is backed by Hammer.Redis; runtime.exs defaults to
# redis://localhost:6379/0 in :dev and :test so this script's defaults
# match without further configuration.
#
# Usage:
#   scripts/start-redis.sh        # foreground (--rm), good for `mix test`
#   scripts/start-redis.sh -d     # detached, container persists across runs

DATA_DIR='redisdata'
IMG='redis:7.4-alpine'
NAME='malan_redis'
PORT='6379'

die ()
{
    echo "$@"
    exit 1
}

# clean up old container if it's laying around
if sudo podman ps -a --format "{{.Names}} {{.Status}}" | grep -E "${NAME}.Created" >/dev/null 2>&1; then
  sudo podman rm "${NAME}"
fi

mkdir -p "${DATA_DIR}" || die "Could not create '${DATA_DIR}' directory for volume"

if [ "$1" = '-d' ]; then
  RM_OR_D='-d'
else
  RM_OR_D='--rm'
fi

sudo podman run \
  ${RM_OR_D} \
  --interactive \
  --tty \
  --publish "127.0.0.1:${PORT}:6379" \
  --volume "$(pwd)/${DATA_DIR}:/data:Z" \
  --name "${NAME}" \
  "${IMG}" \
  redis-server --appendonly yes
