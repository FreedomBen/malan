#!/usr/bin/env bash

# First get a token for the bootstrapped super user
api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               http://localhost:4000/api/sessions/ \
              | jq -r '.data.api_token')"


session_id="$(curl \
               --request GET \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --header "Authorization: Bearer ${api_token}" \
               http://localhost:4000/api/sessions/current \
              | jq -r '.data.id')"


user_id="$(curl \
               --request GET \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --header "Authorization: Bearer ${api_token}" \
               http://localhost:4000/api/users/current \
              | jq -r '.data.id')"


curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/${user_id}/sessions/${session_id}

