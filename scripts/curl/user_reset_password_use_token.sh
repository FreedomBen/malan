#!/usr/bin/env bash

#MALAN_ENDPOINT="http://localhost:4000"
MALAN_ENDPOINT="https://malan-staging.ameelio.org"

# Get this from the email
RESET_TOKEN="5u0ODwJchD4yUuNCaVzbNfcD5Nonj8MKo6HvQa5gHNLRM2RpfVfR1pOZy01FY5BlK"

USERNAME='ben@ameelio.org'

NEW_PASSWORD='password10'

curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "{\"new_password\":\"${NEW_PASSWORD}\"}" \
  "${MALAN_ENDPOINT}/api/users/reset_password/${RESET_TOKEN}"
  #"${MALAN_ENDPOINT}/api/users/${USERNAME}/reset_password/${RESET_TOKEN}"

# Also test the endpoint that receives username and doesn't
