#!/usr/bin/env bash

if [ -z "${RELEASE_VERSION}" ]; then
  RELEASE_VERSION="$(git rev-parse HEAD)"
  echo "RELEASE_VERSION is not set.  Setting to HEAD (${RELEASE_VERSION})"
else
  echo "RELEASE_VERSION already set to '${RELEASE_VERSION}'"
fi

docker push "docker.io/freedomben/malan:latest"
docker push "docker.io/freedomben/malan:${RELEASE_VERSION}"

