#!/usr/bin/env bash

curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
  http://localhost:4000/api/sessions/
