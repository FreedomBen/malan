#!/usr/bin/env bash

DATA_DIR='pgdata_tmp'

#IMG='postgres:11.7-alpine'
IMG='postgres:12.6-alpine'
NAME='malan_postgres'

MAX_CONNECTIONS=200

USER="$(whoami)"

# 'Z' flag in volume mount explained:
# https://prefetch.net/blog/2017/09/30/using-docker-volumes-on-selinux-enabled-servers/

# Mounting /etc/passwd is needed for initdb:
# See:  https://github.com/docker-library/docs/tree/aa1959a855a9b1025057d7efc9e01553ca83a257/postgres#arbitrary---user-notes

die () 
{
  echo "$@"
  exit 1
}

# clean up old container if it's laying around - Finish
if sudo podman ps -a --format "{{.Names}} {{.Status}}" | grep -E "${NAME}.Created" >/dev/null 2>&1; then
  sudo podman rm "$NAME"
fi

if [ -d "${DATA_DIR}" ]; then
  echo "Temporary data directory exists.  Unmounting and deleting"
  sudo umount "$(pwd)/${DATA_DIR}"
  rm -rf "${DATA_DIR}"
fi

mkdir -p "${DATA_DIR}" || die "Could not create '"${DATA_DIR}"' directory for volume"
sudo mount -t tmpfs -o size=1G tmpfs "$(pwd)/${DATA_DIR}"
echo "${DATA_DIR} is mounted.  sleeping 1 second before chowning to avoid race..."
sleep 1
sudo chown -R "${USER}" "${DATA_DIR}"

# This is a little safer than bind mounting in /etc/passwd, which got corrupted
# and rendered my system unbootable.  That's worse than having an extra file
# hanging aroud, trust me
cp /etc/passwd pg_passwd

#if [ "$1" = 'test' ]; then
if [ "$1" = '-d' ]; then
  RM_OR_D='-d'
else
  RM_OR_D='--rm'
fi

sudo podman run \
  $RM_OR_D \
  --interactive \
  --tty \
  --publish '5432:5432' \
  --user "$(id -u):$(id -g)" \
  --volume "$(pwd)/pg_passwd:/etc/passwd:ro,Z" \
  --volume "$(pwd)/"${DATA_DIR}":/var/lib/postgresql/data:Z" \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=postgres \
  --name "$NAME" \
  $IMG \
  -c "max_connections=${MAX_CONNECTIONS}"

if [ "$RM_OR_D" = '--rm' ]; then
  # cleanup pg_passwd if the container was run in the foreground
  echo "Cleaning up pg_passwd..."
  rm -f pg_passwd

  # Clean up the temporary postgres data directory
  echo "Unmounting ${DATA_DIR}"
  sudo umount "$(pwd)/${DATA_DIR}"

  echo "Deleting ${DATA_DIR}"
  rm -r "${DATA_DIR}"

  echo "Done cleaning up ephemeral database"
fi
