#!/usr/bin/env bash

NEW_EMAIL="NewSuperUser1@example.com"
NEW_USERNAME="NewSuperUser1"
NEW_PASSWORD="Password1000"
NEW_LAST_NAME="Super"
NEW_FIRST_NAME="User"

NEW_ROLES='["admin","user"]'

# First get a token for the bootstrapped super user
api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               http://localhost:4000/api/sessions/ \
              | jq -r '.data.api_token')"


curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/current \
  >/dev/null


# Now delete the current session
curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/sessions/current

