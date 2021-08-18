#!/usr/bin/env bash

LATEST_VERSION='2021-08-17a'

docker build \
  -f Dockerfile.prod \
  -t "docker.io/freedomben/${LATEST_VERSION}" \
  .
