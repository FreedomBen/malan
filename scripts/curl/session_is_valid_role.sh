#!/usr/bin/env bash

API_TOKEN='woD78tmE43hFtOf9fxKbNyOwj4IFJ59HvY3r3CPmTFH8OpIiUFiumeuSEh0cbzPoc'
USER_ID='08a65c95-01ab-44ad-ad1b-c25a28b32521'
SESSION_ID='745f4960-52a7-478b-bc51-d83f92f47629'
ROLE='admin'

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${API_TOKEN}" \
  "http://localhost:4000/api/users/${USER_ID}/sessions/${SESSION_ID}/roles/${ROLE}"
