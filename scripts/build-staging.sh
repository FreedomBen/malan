#!/usr/bin/env bash

LATEST_VERSION='20210825154848'

docker build \
  -f Dockerfile.prod \
  -t "docker.io/freedomben/malan-staging:${LATEST_VERSION}" \
  .
