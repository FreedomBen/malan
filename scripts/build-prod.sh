#!/usr/bin/env bash

sudo podman build -f Dockerfile.prod -t docker.io/freedomben/malan-prod:latest .
