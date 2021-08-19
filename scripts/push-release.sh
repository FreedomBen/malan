#!/usr/bin/env bash

LATEST_VERSION='2021-08-17a'

docker push "docker.io/freedomben/malan:${LATEST_VERSION}"
docker push "docker.io/freedomben/malan:latest"
