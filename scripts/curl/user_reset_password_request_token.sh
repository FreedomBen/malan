#!/usr/bin/env bash

#MALAN_ENDPOINT="http://localhost:4000"
MALAN_ENDPOINT="https://malan-staging.ameelio.org"

USERNAME="NewRegularUser1@example.com"

curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"new_password":"supersecretlongpassword"}' \
  "${MALAN_ENDPOINT}/api/users/${USERNAME}/reset_password/"
