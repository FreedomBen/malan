#!/usr/bin/env bash

if [ -z "${RELEASE_VERSION}" ]; then
  RELEASE_VERSION="$(git rev-parse HEAD)"
fi

docker push "docker.io/freedomben/malan:latest"
docker push "docker.io/freedomben/malan:${RELEASE_VERSION}"

