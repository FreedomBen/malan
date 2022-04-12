#!/usr/bin/env bash

LATEST_VERSION='20220401110701'

docker push "docker.io/freedomben/malan-dev:${LATEST_VERSION}"
docker push "docker.io/freedomben/malan-dev:latest"
