#!/usr/bin/env bash

# Default attributes
#curl \
#  --request POST \
#  --header "Accept: application/json" \
#  --header "Content-Type: application/json" \
#  --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
#  http://localhost:4000/api/sessions/

# Forever token
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "CF-Connecting-IP: 127.0.1.1" \
  --data '{"session":{"email":"root@example.com","username":"root","password":"password10","never_expires":true}}' \
  http://localhost:4000/api/sessions/

# 30 second token
#curl \
#  --request POST \
#  --header "Accept: application/json" \
#  --header "Content-Type: application/json" \
#  --data '{"session":{"email":"root@example.com","username":"root","password":"password10","expires_in_seconds":30}}' \
#  http://localhost:4000/api/sessions/
