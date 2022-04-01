#!/usr/bin/env bash

LATEST_VERSION='20220401110701'

docker build \
  -f Dockerfile.arm.prod \
  -t "docker.io/freedomben/malan-arm:${LATEST_VERSION}" \
  -t "docker.io/freedomben/malan-arm:latest" \
  .
