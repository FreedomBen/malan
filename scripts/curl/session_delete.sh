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
  http://localhost:4000/api/users/current
  

# Now create the new user
user_id="$(curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data "{\"user\":{\"email\":\"${NEW_EMAIL}\",\"username\":\"${NEW_USERNAME}\",\"password\":\"${NEW_PASSWORD}\",\"first_name\":\"${NEW_FIRST_NAME}\",\"last_name\":\"${NEW_LAST_NAME}\"}}" \
  http://localhost:4000/api/users/ \
  | jq -r '.data.id')"

# Get the user's ID
if [ "${user_id}" = 'null' ]; then
  echo creating the user failed.  It probably already exists
  exit 1
fi

#echo "api_token is: ${api_token}"
#echo "user_id is: ${user_id}"

# Now update the user
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data "{\"user\":{\"roles\":${NEW_ROLES}}}" \
  http://localhost:4000/api/admin/users/${user_id}
  #http://localhost:4000/api/users/${user_id}

# Get the user to make sure it took hold
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/${user_id}

