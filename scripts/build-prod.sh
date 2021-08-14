#!/usr/bin/env bash

docker build \
  -f Dockerfile.prod \
  -t docker.io/freedomben/malan-prod:latest \
  .
