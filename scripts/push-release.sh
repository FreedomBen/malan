#!/usr/bin/env bash

LATEST_VERSION='20210825193415'

docker push "docker.io/freedomben/malan:${LATEST_VERSION}"
docker push "docker.io/freedomben/malan:latest"
