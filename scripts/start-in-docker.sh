#!/usr/bin/env bash

if [[ "$INIT_DB" =~ [yY] ]]; then
  mix ecto.setup
fi

mix phx.server
