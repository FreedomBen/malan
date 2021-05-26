#!/usr/bin/env bash

NEW_EMAIL="NewSuperUser1@example.com"
NEW_USERNAME="NewSuperUser1"
NEW_PASSWORD="Password1000"
NEW_LAST_NAME="Super"
NEW_FIRST_NAME="User"
NEW_ROLES='["admin","user"]'

NEW_REGULAR_EMAIL="NewRegularUser1@example.com"
NEW_REGULAR_USERNAME="NewRegularUser1"
NEW_REGULAR_PASSWORD="Password1000"
NEW_REGULAR_LAST_NAME="Regular"
NEW_REGULAR_FIRST_NAME="User"

# First get a token for the bootstrapped super user
api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               http://localhost:4000/api/sessions/ \
              | jq -r '.data.api_token')"


# Now create a new admin user with a secret (and long) password
admin_user_id="$(curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data "{\"user\":{\"email\":\"${NEW_EMAIL}\",\"username\":\"${NEW_USERNAME}\",\"password\":\"${NEW_PASSWORD}\",\"first_name\":\"${NEW_FIRST_NAME}\",\"last_name\":\"${NEW_LAST_NAME}\"}}" \
  http://localhost:4000/api/users/ \
  | jq -r '.data.id')"


if [ "$admin_user_id" = "null" ]; then
  echo "Error creating new admin user.  Make sure the user doesn't already exist"
  exit 2
fi

echo "admin_user_id is ${admin_user_id}"

# Make the new user an admin
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data "{\"user\":{\"roles\":${NEW_ROLES}}}" \
  http://localhost:4000/api/admin/users/${admin_user_id}


# Switch to using a token for the new user
regular_api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data "{\"session\":{\"email\":\"${NEW_EMAIL}\",\"username\":\"${NEW_USERNAME}\",\"password\":\"${NEW_PASSWORD}\"}}" \
               http://localhost:4000/api/sessions/ \
              | jq -r '.data.api_token')"


# Now create a regular user who's password we can change
regular_user_id="$(curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${regular_api_token}" \
  --data "{\"user\":{\"email\":\"${NEW_REGULAR_EMAIL}\",\"username\":\"${NEW_REGULAR_USERNAME}\",\"password\":\"${NEW_REGULAR_PASSWORD}\",\"first_name\":\"${NEW_REGULAR_FIRST_NAME}\",\"last_name\":\"${NEW_REGULAR_LAST_NAME}\"}}" \
  http://localhost:4000/api/users/ \
  | jq -r '.data.id')"


if [ "$regular_user_id" = "null" ]; then
  echo "Error creating new regular user.  Make sure the user doesn't already exist"
  exit 2
fi

# Now update the user's password
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${regular_api_token}" \
  --data '{"user":{"password":"supersecretlongpassword"}}' \
  http://localhost:4000/api/admin/users/${regular_user_id}
