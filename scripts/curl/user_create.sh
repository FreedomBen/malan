#!/usr/bin/env bash

MALAN_HOST='https://malan-staging.ameelio.org'
#MALAN_HOST='http://localhost:4000'

# Regular user
NEW_EMAIL="ben@ameelio.org"
NEW_USERNAME="ben@ameelio.org"
NEW_PASSWORD="Password1000"
NEW_LAST_NAME="McTesterson"
NEW_FIRST_NAME="Testy"


# Now create the new user
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data "{\"user\":{\"email\":\"${NEW_EMAIL}\",\"username\":\"${NEW_USERNAME}\",\"password\":\"${NEW_PASSWORD}\",\"first_name\":\"${NEW_FIRST_NAME}\",\"last_name\":\"${NEW_LAST_NAME}\"}}" \
  "${MALAN_HOST}/api/users/"

