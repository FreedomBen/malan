#!/usr/bin/env bash

MALAN_ENDPOINT='https://malan.ameelio.org'

api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               "${MALAN_ENDPOINT}/api/sessions/" \
              | jq -r .data.api_token)"

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  "${MALAN_ENDPOINT}/api/users/whoami"
  
