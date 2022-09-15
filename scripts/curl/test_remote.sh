#!/usr/bin/env bash

#MALAN_ENDPOINT="http://localhost:4000"
#MALAN_ENDPOINT="https://malan-staging.ameelio.org"
MALAN_ENDPOINT="https://malan-prod.ameelio.org"
#MALAN_ENDPOINT="https://accounts.ameelio.org"

USER_NAME='root'
USER_EMAIL='root@example.com'
USER_PASSWORD=''


# First get a token for the user
api_token="$(curl \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data "{\"session\":{\"email\":\"$USER_EMAIL\",\"username\":\"$USER_NAME\",\"password\":\"$USER_PASSWORD\"}}" \
               "${MALAN_ENDPOINT}/api/sessions/" \
              | jq -r '.data.api_token')"


if [ "$api_token" = "null" ]; then
  echo "Error creating new session.  Make sure the user exists and password is correct"
  exit 2
fi

echo "new_user_id is ${new_user_id}"

# Get user info in a loop
count=0
while true; do
  echo "Count is '${count}'"
  time curl \
    --request GET \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${api_token}" \
    "${MALAN_ENDPOINT}/api/sessions/current"
  echo ''
  count="$((count + 1))"
  sleep 2
done
