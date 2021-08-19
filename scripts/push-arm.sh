#!/usr/bin/env bash

LATEST_VERSION='2021-08-19-17-00-53'

docker push "docker.io/freedomben/malan-arm:${LATEST_VERSION}"
docker push "docker.io/freedomben/malan-arm:latest"
