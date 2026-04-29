#!/usr/bin/env bash

NAME='malan_redis'

die ()
{
    echo "$@"
    exit 1
}

sudo podman stop "${NAME}"
sudo podman rm "${NAME}"
