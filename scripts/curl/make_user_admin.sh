#!/usr/bin/env bash

USERNAME="username-to-promote"

NEW_ROLES='["admin","user"]'

# First get a token for the bootstrapped super user
api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
               http://localhost:4000/api/sessions/ \
              | jq -r '.data.api_token')"

if [ "${api_token}" = "null" ]; then
  echo "Error getting admin token.  Check root credentials."
  exit 1
fi

# Look up the user by username by paging through /api/admin/users
user_id="null"
page=0
page_size=100

while : ; do
  page_json="$(curl \
                 --silent \
                 --request GET \
                 --header "Accept: application/json" \
                 --header "Content-Type: application/json" \
                 --header "Authorization: Bearer ${api_token}" \
                 "http://localhost:4000/api/admin/users?page_num=${page}&page_size=${page_size}")"

  match="$(echo "${page_json}" | jq -r --arg u "${USERNAME}" '.data[] | select(.username == $u) | .id')"

  if [ -n "${match}" ] && [ "${match}" != "null" ]; then
    user_id="${match}"
    break
  fi

  count="$(echo "${page_json}" | jq -r '.data | length')"
  if [ "${count}" = "0" ] || [ "${count}" = "null" ]; then
    break
  fi

  page=$((page + 1))
done

if [ "${user_id}" = "null" ]; then
  echo "Could not find a user with username '${USERNAME}'."
  exit 2
fi

echo "user_id is ${user_id}"

# Promote the user to admin
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data "{\"user\":{\"roles\":${NEW_ROLES}}}" \
  http://localhost:4000/api/admin/users/${user_id}
