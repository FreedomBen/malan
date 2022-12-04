#!/usr/bin/env bash

list_files()
{
  echo "Eligible files:"
  fd --type f '.*-[a-f0-9]{32}\.(css|txt|png|svg|webp|ico)(\.gz)?$' priv/static/
}

delete_files()
{
  echo "Deleting..."
  fd --type f '.*-[a-f0-9]{32}\.(css|txt|png|svg|webp|ico)(\.gz)?$' priv/static/ --exec rm {} \;
}

if [[ "${1}" =~ [dDrR] ]]; then
  list_files
  delete_files
else
  echo "DRY RUN ONLY.  Pass -d | -r to run"
  list_files
fi
