#!/usr/bin/env bash

MALAN_HOST='https://malan-staging.ameelio.org'

# Regular user
NEW_EMAIL="TestUser1@example.com"
NEW_USERNAME="TestUser1"
NEW_PASSWORD="Password1000"
NEW_LAST_NAME="McTesterson"
NEW_FIRST_NAME="Testy"

# First get a token for the bootstrapped super user
api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               "${MALAN_HOST}/api/sessions/" \
              | jq -r '.data.api_token')"

# Now create the new user
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data "{\"user\":{\"email\":\"${NEW_EMAIL}\",\"username\":\"${NEW_USERNAME}\",\"password\":\"${NEW_PASSWORD}\",\"first_name\":\"${NEW_FIRST_NAME}\",\"last_name\":\"${NEW_LAST_NAME}\"}}" \
  "${MALAN_HOST}/api/users/"

