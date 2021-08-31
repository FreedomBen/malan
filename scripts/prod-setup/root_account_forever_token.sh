#!/usr/bin/env bash

# If you are using this against a deployed malan instance, set these accordingly
MALAN_PROTOCOL='http'
MALAN_HOSTNAME='localhost:4000'

MALAN_ROOT_USERNAME='root'
MALAN_ROOT_PASSWORD='password10'


if [ -z "$MALAN_ROOT_USERNAME" ]; then
  echo -e "Please set env var MALAN_ROOT_USERNAME and try again"
  exit 1
fi

if [ -z "$MALAN_ROOT_PASSWORD" ]; then
  echo -e "Please set env var MALAN_ROOT_PASSWORD to the root password and try again"
  exit 1
fi

echo -e "Creating a session as super user..."

response="$(curl -s \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data "{\"session\":{\"username\":\"${MALAN_ROOT_USERNAME}\",\"password\":\"${MALAN_ROOT_PASSWORD}\",\"never_expires\":true}}" \
               "${MALAN_PROTOCOL}://${MALAN_HOSTNAME}/api/sessions/")"

api_token="$(echo "$response" | jq -r '.data.api_token')"

if [ "$api_token" = "null" ]; then
  echo -e "Error creating a session as super user.  Make sure MALAN_ROOT_USERNAME and MALAN_ROOT_PASSWORD are set to the correct root username and password."
  echo -e "Response: ${response}"
  exit 2
fi

echo -e "Got a valid token.  API token is:  '${api_token}'"
echo -e "Full response:  ${response}"

