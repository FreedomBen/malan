#!/usr/bin/env bash

MALAN_ENDPOINT="https://malan.ameelio.org"
API_TOKEN="<fill-me-in>"
NEW_PASSWORD="2YzMtYzdmN2KdfgkWr"
USER_ID="<fill-me-in>"

# As an admin, Update the user's password through the admin user update
# endpoint at PUT /api/admin/users/:id
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${API_TOKEN}" \
  --data "{\"user\":{\"password\":\"${NEW_PASSWORD}\"}}" \
  "${MALAN_ENDPOINT}/api/admin/users/${USER_ID}"

# As a user, update own password through the user update endpoint at
# at PUT /api/users/:id
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${API_TOKEN}" \
  --data "{\"user\":{\"password\":\"${NEW_PASSWORD}\"}}" \
  "${MALAN_ENDPOINT}/api/users/${USER_ID}"
