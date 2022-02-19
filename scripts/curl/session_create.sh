#!/usr/bin/env bash

#MALAN_ENDPOINT="http://localhost:4000"
MALAN_ENDPOINT="https://malan-staging.ameelio.org"
#MALAN_ENDPOINT="https://malan.ameelio.org"

USERNAME='root'
PASSWORD='password10'

# Default attributes
#curl \
#  --request POST \
#  --header "Accept: application/json" \
#  --header "Content-Type: application/json" \
#  --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
#  "${MALAN_ENDPOINT}/api/sessions/"

# Forever token
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "CF-Connecting-IP: 127.0.1.1" \
  --data "{\"session\":{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\",\"never_expires\":true}}" \
  "${MALAN_ENDPOINT}/api/sessions/"

## 30 second token
#curl \
#  --request POST \
#  --header "Accept: application/json" \
#  --header "Content-Type: application/json" \
#  --data "{\"session\":{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\",\"expires_in_seconds\":30}}" \
#  "${MALAN_ENDPOINT}/api/sessions/"
