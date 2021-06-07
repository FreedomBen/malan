#!/usr/bin/env bash

sudo podman push --authfile ~/.docker/config.json docker.io/freedomben/malan-dev:latest
sudo podman push --authfile ~/.docker/config.json docker.io/freedomben/malan:latest
