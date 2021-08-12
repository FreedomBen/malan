#!/usr/bin/env bash

MALAN_ENDPOINT="http://localhost:4000"
#MALAN_ENDPOINT="https://malan-staging.ameelio.org

NEW_EMAIL="NewRegularUser1@example.com"
NEW_USERNAME="NewRegularUser1"
NEW_PASSWORD="Password1000"
NEW_LAST_NAME="Regular"
NEW_FIRST_NAME="User"

RESET_PASSWORD="hahahahahahaha"

# First get a token for the bootstrapped super user
api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               "${MALAN_ENDPOINT}/api/sessions/" \
              | jq -r '.data.api_token')"


# Now create a new admin user with a secret (and long) password
new_user_id="0f08758f-fd00-4db9-b216-982442571d75"
#new_user_id="$(curl \
#  --request POST \
#  --header "Accept: application/json" \
#  --header "Content-Type: application/json" \
#  --header "Authorization: Bearer ${api_token}" \
#  --data "{\"user\":{\"email\":\"${NEW_EMAIL}\",\"username\":\"${NEW_USERNAME}\",\"password\":\"${NEW_PASSWORD}\",\"first_name\":\"${NEW_FIRST_NAME}\",\"last_name\":\"${NEW_LAST_NAME}\"}}" \
#  http://localhost:4000/api/users/ \
#  | jq -r '.data.id')"


if [ "$new_user_id" = "null" ]; then
  echo "Error creating new user.  Make sure the user doesn't already exist"
  exit 2
fi

echo "new_user_id is ${new_user_id}"


# Now reset the user's password
password_reset_token="$(curl \
                  --request POST \
                  --header "Accept: application/json" \
                  --header "Content-Type: application/json" \
                  --header "Authorization: Bearer ${api_token}" \
                  "${MALAN_ENDPOINT}/api/admin/users/${new_user_id}/reset_password" \
                  | jq -r '.data.password_reset_token')"

echo "password_reset_token is: ${password_reset_token}"

curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data '{"new_password":"supersecretlongpassword"}' \
  "${MALAN_ENDPOINT}/api/admin/users/${new_user_id}/reset_password/${password_reset_token}"
