#!/usr/bin/env bash

LATEST_VERSION='20210819172734'

docker build \
  -f Dockerfile.arm \
  -t "docker.io/freedomben/malan-arm:${LATEST_VERSION}" \
  -t "docker.io/freedomben/malan-arm:latest" \
  .
