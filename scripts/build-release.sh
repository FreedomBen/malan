#!/usr/bin/env bash

LATEST_VERSION='20210825193415'

docker build \
  -f Dockerfile.prod \
  -t "docker.io/freedomben/malan:${LATEST_VERSION}" \
  -t "docker.io/freedomben/malan:latest" \
  .
