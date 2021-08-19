#!/usr/bin/env bash

LATEST_VERSION='2021-08-19-17-00-53'

docker build \
  -f Dockerfile.prod \
  -t "docker.io/freedomben/malan-arm:${LATEST_VERSION}" \
  -t "docker.io/freedomben/malan-arm:latest" \
  .
