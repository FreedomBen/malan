#!/usr/bin/env bash

# This script can be used to create a new admin user, most often for
# service accounts.  
#




# Put the existing admin user credentials in an environment variable called MALAN_NEW_ROOT_PW
#
# If MALAN_OLD_ROOT_PW is set, that value will be used to create a session
# for the root user.  If not set, the default will be used.
#
# MALAN_HOSTNAME should be set to the hostname for your Malan deployment


MALAN_PROTOCOL='http'
#MALAN_PROTOCOL='https'

#MALAN_HOSTNAME='malan.example.com'
MALAN_HOSTNAME='localhost:4000'

MALAN_OLD_ADMIN_USERNAME='root'

MALAN_NEW_ADMIN_EMAIL='admin3@example.com'
MALAN_NEW_ADMIN_USERNAME='admin3'
MALAN_NEW_ADMIN_PASSWORD='adminadminadmin'
MALAN_NEW_ADMIN_FIRST_NAME='Admin'
MALAN_NEW_ADMIN_LAST_NAME='User'

NEW_ROLES='["admin","user"]'

#MALAN_ROOT_PW="password10"
#MALAN_NEW_ROOT_PW="password10"

if [ -z "$MALAN_HOSTNAME" ]; then
  echo -e "Please set env var MALAN_HOSTNAME and try again"
  exit 1
fi

if [ -z "$MALAN_ROOT_PW" ]; then
  echo -e "Env var MALAN_ROOT_PW is not set.  Assuming default"
  MALAN_OLD_ROOT_PW="password10"
fi

echo -e "Creating a session as super user..."
# First get a token for the bootstrapped super user
api_token="$(curl -s \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"username":"root","password":"password10"}}' \
               "${MALAN_PROTOCOL}://${MALAN_HOSTNAME}/api/sessions/" \
              | jq -r '.data.api_token')"


if [ "$api_token" = "null" ]; then
  echo -e "Error creating a session as super user.  Make sure MALAN_ROOT_PW is set to the correct root password."
  exit 2
fi

echo -e "Got a valid token for root user.  Creating a new user..."

new_user_response="$(curl -s \
              --request POST \
              --header "Accept: application/json" \
              --header "Content-Type: application/json" \
              --header "Authorization: Bearer ${api_token}" \
              --data "{\"user\":{\"email\":\"${MALAN_NEW_ADMIN_EMAIL}\",\"username\":\"${MALAN_NEW_ADMIN_USERNAME}\",\"password\":\"${MALAN_NEW_ADMIN_PASSWORD}\",\"first_name\":\"${MALAN_NEW_ADMIN_FIRST_NAME}\",\"last_name\":\"${MALAN_NEW_ADMIN_LAST_NAME}\"}}" \
              "${MALAN_PROTOCOL}://${MALAN_HOSTNAME}/api/users/")"

user_id="$(echo "$new_user_response" | jq -r '.data.id')"

if [ "$?" != "0" ]; then
  echo -e "Error reaching Malan.  Make sure hostname and protocol are correct"
  exit 4
elif $(echo "$new_user_response" | grep -E '^..data' >/dev/null 2>&1) ; then
  echo -e "User created successfully.  User ID is '${user_id}'.  Upgrading to an admin..."
else
  echo -e "Error creating new user"
  echo "$new_user_response"
  exit 5
fi


# Now make the user an admin
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data "{\"user\":{\"roles\":${NEW_ROLES}}}" \
  "${MALAN_PROTOCOL}://${MALAN_HOSTNAME}/api/admin/users/${user_id}"


if [ "$?" != "0" ]; then
  echo -e "\n\nError reaching Malan.  Make sure hostname and protocol are correct"
  exit 4
else
  echo -e "\n\nSuccessfully made user ID '${user_id}' username '${MALAN_NEW_ADMIN_USERNAME}' an admin"
fi
