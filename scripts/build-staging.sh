#!/usr/bin/env bash

LATEST_VERSION='2021-08-17'

docker build \
  -f Dockerfile.prod \
  -t "docker.io/freedomben/malan-staging:${LATEST_VERSION}" \
  .
