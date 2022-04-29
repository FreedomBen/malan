#!/usr/bin/env bash

if [ -z "${RELEASE_VERSION}" ]; then
  RELEASE_VERSION="$(git rev-parse HEAD)"
  echo "RELEASE_VERSION is not set.  Setting to HEAD (${RELEASE_VERSION})"
else
  echo "RELEASE_VERSION already set to '${RELEASE_VERSION}'"
fi

docker build \
  -f Dockerfile.arm.prod \
  -t "docker.io/freedomben/malan-arm:${RELEASE_VERSION}" \
  -t "docker.io/freedomben/malan-arm:latest" \
  .
