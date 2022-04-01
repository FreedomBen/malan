#!/usr/bin/env bash

LATEST_VERSION='20220401110701'

docker build \
  -f Dockerfile.arm \
  -t "docker.io/freedomben/malan-arm-dev:${LATEST_VERSION}" \
  -t "docker.io/freedomben/malan-arm-dev:latest" \
  .
