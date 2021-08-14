#!/usr/bin/env bash

docker build \
  -f Dockerfile.prod \
  -t docker.io/freedomben/malan-prod:2021-08-13 \
  .
