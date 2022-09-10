#!/usr/bin/env bash

LATEST_VERSION='20220401110701'

docker build \
  -f Dockerfile.prod \
  -t "docker.io/freedomben/malan-prod:${LATEST_VERSION}" \
  .
