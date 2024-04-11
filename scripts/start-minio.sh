#!/usr/bin/env bash

INITIAL_BUCKET_NAME='malan-dev'

DATA_DIR='miniodata'

IMG='quay.io/minio/minio'
NAME='malan_minio'


# 'Z' flag in volume mount explained:
# https://prefetch.net/blog/2017/09/30/using-docker-volumes-on-selinux-enabled-servers/

die () 
{
    echo "$@"
    exit 1
}

# clean up old container if it's laying around - Finish
if podman ps -a --format "{{.Names}} {{.Status}}" | grep -E "${NAME}.Created" >/dev/null 2>&1; then
  podman rm "$NAME"
fi

mkdir -p "${DATA_DIR}" || die "Could not create '${DATA_DIR}' directory for volume"

# Create initial bucket
mkdir -p "${DATA_DIR}/${INITIAL_BUCKET_NAME}" || die "Could not create initial bucket directory"

if [ "$1" = '-d' ]; then
  RM_OR_D='-d'
else
  RM_OR_D='--rm'
fi

podman run \
  $RM_OR_D \
  --interactive \
  --tty \
  --publish '9000:9000' \
  --publish '9001:9001' \
  --volume "$(pwd)/${DATA_DIR}:/data:Z" \
  --env MINIO_ROOT_USER=minioadmin \
  --env MINIO_ROOT_PASSWORD=minioadmin \
  --name "$NAME" \
  $IMG \
  server /data --console-address ":9001"

if [ "$RM_OR_D" = '--rm' ]; then
  # cleanup pg_passwd if the container was run in the foreground
  rm -f pg_passwd
fi
