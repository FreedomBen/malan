#!/usr/bin/env bash

# This script can be used to rotate the password for the root user.
# In new production deployments, it is VERY IMPORTANT TO DO THIS
#
# Put the new password in an environment variable called MALAN_NEW_ROOT_PW
#
# If MALAN_OLD_ROOT_PW is set, that value will be used to create a session
# for the root user.  If not set, the default will be used.
#
# MALAN_HOSTNAME should be set to the hostname for your Malan deployment


MALAN_ROOT_USERNAME='root'
MALAN_PROTOCOL='http'
#MALAN_PROTOCOL='https'

#MALAN_HOSTNAME='malan.example.com'
MALAN_HOSTNAME='localhost:4000'
#MALAN_OLD_ROOT_PW="password10"
#MALAN_NEW_ROOT_PW="password10"

if [ -z "$MALAN_HOSTNAME" ]; then
  echo -e "Please set env var MALAN_HOSTNAME and try again"
  exit 1
fi

if [ -z "$MALAN_NEW_ROOT_PW" ]; then
  echo -e "Please set env var MALAN_NEW_ROOT_PW to the new password and try again"
  exit 1
fi

if [ -z "$MALAN_OLD_ROOT_PW" ]; then
  echo -e "Env var MALAN_OLD_ROOT_PW is not set.  Assuming default"
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
  echo -e "Error creating a session as super user.  Make sure MALAN_OLD_ROOT_PW is set to the correct root password."
  exit 2
fi

echo -e "Got a valid token.  Changing the root user's password..."

# Now get the root user's ID
root_user_id="$(curl -s \
                  --request GET \
                  --header "Accept: application/json" \
                  --header "Content-Type: application/json" \
                  --header "Authorization: Bearer ${api_token}" \
                  "${MALAN_PROTOCOL}://${MALAN_HOSTNAME}/api/users/whoami" \
                  | jq -r '.data.user_id')"
      

if [ "$root_user_id" = "null" ]; then
  echo -e "\nError retrieving root user's ID.  Make sure you are authenticated"
  exit 3
fi


# Now update the user's password
response="$(curl -s \
              --request PUT \
              --header "Accept: application/json" \
              --header "Content-Type: application/json" \
              --header "Authorization: Bearer ${api_token}" \
              --data "{\"user\":{\"password\":\"${MALAN_NEW_ROOT_PW}\"}}" \
              "${MALAN_PROTOCOL}://${MALAN_HOSTNAME}/api/admin/users/${root_user_id}")"

echo "$response"
if [ "$?" != "0" ]; then
  echo -e "\n\nError reaching Malan.  Make sure hostname and protocol are correct"
  exit 4
elif $(echo "$response" | grep -E '^..data' >/dev/null 2>&1) ; then
  echo -e "\n\nSuccessfully set new root password!"
  exit 0
else
  echo -e "\n\nError setting new root password.  Make sure it meets the password requirements and try again"
  exit 5
fi
