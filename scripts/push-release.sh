#!/usr/bin/env bash

LATEST_VERSION='20210819170954'

docker push "docker.io/freedomben/malan:${LATEST_VERSION}"
docker push "docker.io/freedomben/malan:latest"
