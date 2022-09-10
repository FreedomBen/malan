#!/usr/bin/env bash

LATEST_VERSION='20220803114929'

docker build \
  -f Dockerfile \
  -t "docker.io/freedomben/malan-dev:${LATEST_VERSION}" \
  .
