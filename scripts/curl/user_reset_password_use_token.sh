#!/usr/bin/env bash

#MALAN_ENDPOINT="http://localhost:4000"
MALAN_ENDPOINT="https://malan-staging.ameelio.org"

# Get this from the email
RESET_TOKEN="Ce7h4bMl7vkMymKPvFt6ykVLNVXRW1u9KdvLICC1z3QflWSw5Aa0YCdTfq3on1sxS"

USERNAME='ben@ameelio.org'

NEW_PASSWORD='floyvenmaven'

curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "{\"new_password\":\"${NEW_PASSWORD}\"}" \
  "${MALAN_ENDPOINT}/api/users/reset_password/${RESET_TOKEN}"
  #"${MALAN_ENDPOINT}/api/users/${USERNAME}/reset_password/${RESET_TOKEN}"

# Also test the endpoint that receives username and doesn't
