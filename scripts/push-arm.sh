#!/usr/bin/env bash

LATEST_VERSION='20210819172734'

docker push "docker.io/freedomben/malan-arm:${LATEST_VERSION}"
docker push "docker.io/freedomben/malan-arm:latest"
