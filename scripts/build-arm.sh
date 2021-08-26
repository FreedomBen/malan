#!/usr/bin/env bash

LATEST_VERSION='20210825193415'

docker build \
  -f Dockerfile.arm \
  -t "docker.io/freedomben/malan-arm:${LATEST_VERSION}" \
  -t "docker.io/freedomben/malan-arm:latest" \
  .
