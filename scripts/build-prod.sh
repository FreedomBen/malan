#!/usr/bin/env bash

LATEST_VERSION='20210819170954'

docker build \
  -f Dockerfile.prod \
  -t "docker.io/freedomben/malan-prod:${LATEST_VERSION}" \
  .
