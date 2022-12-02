#!/usr/bin/env bash

PROJECT_NAME='malan'

remove_file()
{
  if [ -f "$1" ]; then
    echo "Deleting $1"
    rm "$1"
  else
    echo "Oops -- $1 doesn't exist so can't delete"
  fi
}

if [ -z "${2}" ]; then
  echo "First arg should be context, second arg model (singular) name."
  echo "  Example: If generated as 'Helps SupportRequest support_requests' then args here will be 'Helps support_request'"
  exit 1
else
  context="$(echo "$1" | awk '{ print tolower($0) }')"
  model="$(echo "$2" | awk '{ print tolower($0) }')"

  echo "context: ${context}"
  echo "model: ${model}"

  echo "Deleting the following model files"
  remove_file "lib/${PROJECT_NAME}_web/controllers/${model}_controller.ex"
  remove_file "lib/${PROJECT_NAME}_web/views/${model}_view.ex"
  remove_file "lib/${PROJECT_NAME}/${context}/${model}.ex"
  remove_file "lib/${PROJECT_NAME}/${context}.ex"

  remove_file "test/${PROJECT_NAME}_web/controllers/${model}_controller_test.exs"
  remove_file "test/${PROJECT_NAME}/${context}_test.exs"
  remove_file "test/support/fixtures/${context}_fixtures.ex"

  for f in priv/repo/migrations/*_create_${model}s.exs; do
    remove_file "${f}"
  done

  rmdir "lib/${PROJECT_NAME}/${context}"

  #find lib/ -iname "*${model}*"
  #find test/ -iname "*${model}*"
  #find . -iname '*${2}*' -exec rm -r {} \;
  #find . -iname '*${2}*' -exec rm -r {} \;

  echo "Deleting the following context files.  If this is not an empty context, this will require you to restore from git"
fi
