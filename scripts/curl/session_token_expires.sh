#!/usr/bin/env bash

#VERBOSE='-v'
VERBOSE=''

MALAN_ENDPOINT='http://localhost:4000'
#MALAN_ENDPOINT='https://malan-staging.ameelio.org'
#MALAN_ENDPOINT='https://malan.ameelio.org'

USERNAME='root'
PASSWORD='password10'

api_token="$(curl -s \
               --request POST \
               --header "Accept: application/json" \
               --header "Content-Type: application/json" \
               --data "{\"session\":{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\",\"expires_in_seconds\":3}}" \
               "${MALAN_ENDPOINT}/api/sessions/" \
              | jq -r .data.api_token)"

echo
echo "Got api token:  ${api_token}"
echo
echo "Verifying token through whoami..."
echo

curl -s ${VERBOSE} \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  "${MALAN_ENDPOINT}/api/users/whoami" \
  | jq -r
  

echo
echo "Waiting 5 seconds for token to expire ..."
echo
sleep 10

curl -s ${VERBOSE} \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  "${MALAN_ENDPOINT}/api/users/whoami" \
  | jq -r
  
