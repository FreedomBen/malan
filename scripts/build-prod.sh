#!/usr/bin/env bash

LATEST_VERSION='20210819172734'

docker build \
  -f Dockerfile.prod \
  -t "docker.io/freedomben/malan-prod:${LATEST_VERSION}" \
  .
