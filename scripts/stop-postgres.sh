#!/usr/bin/env bash

NAME='malan_postgres'

die () 
{
    echo "$@"
    exit 1
}

sudo podman stop "$NAME"
sudo podman rm "$NAME"
rm -f pg_passwd
