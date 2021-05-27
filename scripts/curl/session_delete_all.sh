#!/usr/bin/env bash

NEW_EMAIL="NewSuperUser1@example.com"
NEW_USERNAME="NewSuperUser1"
NEW_PASSWORD="Password1000"
NEW_LAST_NAME="Super"
NEW_FIRST_NAME="User"

NEW_ROLES='["admin","user"]'

# First get a token for the bootstrapped super user
api_token1="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               http://localhost:4000/api/sessions/ \
              | jq -r '.data.api_token')"

api_token2="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               http://localhost:4000/api/sessions/ \
              | jq -r '.data.api_token')"

api_token3="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               http://localhost:4000/api/sessions/ \
              | jq -r '.data.api_token')"


echo -e "\n\nVerifying token 1"

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token1}" \
  http://localhost:4000/api/sessions/current

echo -e "\n\nVerifying token 2"

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token2}" \
  http://localhost:4000/api/sessions/current

echo -e "\n\nVerifying token 3"

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token3}" \
  http://localhost:4000/api/sessions/current

echo -e "\n\nDeleting token 1"

curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token1}" \
  http://localhost:4000/api/sessions/current

echo -e "\n\nDeleting token 2"

curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token2}" \
  http://localhost:4000/api/sessions/current

echo -e "\n\nDeleting token 3"

curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token3}" \
  http://localhost:4000/api/sessions/current

echo -e "\n\nVerifying token 1 is deleted (expect unauthorized)"

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token1}" \
  http://localhost:4000/api/sessions/current

echo -e "\n\nVerifying token 2 is deleted (expect unauthorized)"

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token2}" \
  http://localhost:4000/api/sessions/current

echo -e "\n\nVerifying token 3 is deleted (expect unauthorized)"

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token3}" \
  http://localhost:4000/api/sessions/current

