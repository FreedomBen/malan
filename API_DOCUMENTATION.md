# Malan HTTP API

Malan is a Phoenix 1.8 (app version `0.1.0`) authentication service that issues API tokens and manages users, sessions, and audit logs. The OpenAPI 3.1 spec in `priv/openapi/openapi.yaml` is generated from the router as of December 23, 2025.

## Base URLs
- Same-origin (Swagger UI): `/`
- Production: `https://accounts.ameelio.org`
- Staging: `https://accounts.ameelio.xyz`
- Development: `http://localhost:4000`

## Authentication & Tokens
- Pass the token returned from **POST /api/sessions** as `Authorization: Bearer <token>`.
- Most `/api` routes require a token; unauthenticated exceptions are called out below. Login failures return `403` (`ForbiddenAuth`) and locked accounts return `423`.
- Terms of Service and Privacy Policy acceptance may be enforced depending on deployment configuration. If you receive HTTP 461 or 462, update your user with `accept_tos: true` and/or `accept_privacy_policy: true`.

## Common Response Shape
Successful responses:
```json
{ "ok": true, "code": 200, "data": { ... } }
```
Error responses:
```json
{ "ok": false, "code": 422, "detail": "Unprocessable Entity", "message": "...", "errors": {...} }
```

## Error Codes
- 400 Bad Request
- 401 Unauthorized (authenticated but not allowed; e.g., not owner/admin)
- 403 Forbidden (missing/invalid token, expired/revoked session)
- 403 ForbiddenAuth (invalid username/password/location on login)
- 404 Not Found
- 422 Unprocessable Entity (validation/pagination errors)
- 423 Locked (locked user)
- 429 Too Many Requests (rate limits)
- 461 Terms of Service Required
- 462 Privacy Policy Required
- 500 Internal Server Error

## Pagination
Endpoints that list records accept `page_num` (default `0`) and `page_size` (default `10`, max `100` where enforced). User and session-extension list responses include these values; other lists return just the data array.

## Rate Limits
- Login: 429 when the credential rate limiter is exceeded.
- Password reset requests: 1 every 3 minutes, up to 3 per 24 hours (configurable via env vars `PASSWORD_RESET_*`).
- General request rate limiting is backed by Hammer; Redis can be used in production (`HAMMER_REDIS_URL`).

## Public Endpoints (no token required)

### Create User
`POST /api/users`

Body:
```json
{
  "user": {
    "email": "user@example.com",
    "username": "user@example.com",
    "password": "password123",
    "first_name": "Jane",
    "last_name": "Doe",
    "display_name": "Jane Doe",
    "nick_name": "JD",
    "gender": "Non-binary",
    "race": ["Asian"],
    "ethnicity": "Hispanic or Latinx",
    "preferences": {
      "theme": "light",
      "display_name_pref": "full_name",
      "display_middle_initial_only": false
    },
    "custom_attrs": { "source": "signup-form" },
    "approved_ips": ["1.2.3.4"],
    "addresses": [{
      "name": "Home",
      "line_1": "123 Main St",
      "line_2": "Apt 5",
      "city": "Anytown",
      "state": "CA",
      "postal": "12345",
      "country": "US",
      "primary": true
    }],
    "phone_numbers": [{
      "number": "+14155550123",
      "primary": true
    }]
  }
}
```
- Required fields: `username`, `email`, `password`, `first_name`, `last_name`.
- Optional profile data: middle/suffix/prefix names, `display_name`, `nick_name`, `birthday`, `sex`, `gender` (enumerated; e.g., Cis Female, Trans Man, Non-binary), `race` (American Indian or Alaska Native, Asian, Black or African American, Native Hawaiian or Other Pacific Islander, White), `ethnicity` (Hispanic or Latinx / Not Hispanic or Latinx), `weight`, `height`.
- Preferences enum: `theme` (`light`|`dark`), `display_name_pref` (`full_name`|`nick_name`|`custom`), `display_middle_initial_only` (bool).
- You may inline `addresses` and `phone_numbers` during creation; address fields require `line_2` in this API.

Response (`201 Created`):
```json
{
  "ok": true,
  "code": 201,
  "data": {
    "id": "c0c7d53e-7a76-4f4f-9f1e-e5a0f6e9c8b1",
    "username": "user@example.com",
    "email": "user@example.com",
    "roles": ["user"],
    "latest_tos_accept_ver": null,
    "latest_pp_accept_ver": null,
    "preferences": { ... },
    "approved_ips": ["1.2.3.4"]
  }
}
```
- Additional fields present on the `data` object: `email_verified` timestamp (nullable), `locked_at/locked_by` when locked, `tos_accepted` / `privacy_policy_accepted`, acceptance event histories, and any `custom_attrs` you provided.

### Create Session (Login)
`POST /api/sessions`

Body:
```json
{
  "session": {
    "username": "user@example.com",
    "password": "password123",
    "location": "nyc-lab",                    // optional audit tag
    "never_expires": false,                   // optional, default false
    "expires_in_seconds": 3600,               // optional, default 7 days (604800)
    "extendable_until_seconds": 2419200,      // optional, default 28 days
    "max_extension_secs": 604800,             // optional, default 7 days
    "valid_only_for_ip": false,
    "valid_only_for_approved_ips": false
  }
}
```

Response (`201 Created`):
```json
{
  "ok": true,
  "code": 201,
  "data": {
    "id": "c2f8c1aa-9a3e-4d58-9f3b-e7f0c2c94a10",
    "user_id": "c0c7d53e-7a76-4f4f-9f1e-e5a0f6e9c8b1",
    "api_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "authenticated_at": "2024-12-16T12:00:00Z",
    "ip_address": "203.0.113.10",
    "location": null,
    "expires_at": "2025-01-01T12:00:00Z",
    "extendable_until": "2025-01-29T12:00:00Z",
    "max_extension_secs": 604800,
    "valid_only_for_ip": false,
    "valid_only_for_approved_ips": false,
    "is_valid": true
  }
}
```
- `api_token` is only present in the creation response; subsequent session fetches omit it.
- Invalid credentials return `403 ForbiddenAuth`; locked users return `423`; excessive login attempts return `429 Too Many Requests`.
- `never_expires: true` issues a non-expiring session that can still be revoked; `valid_only_for_ip` and `valid_only_for_approved_ips` further restrict token use.

### Who Am I
`GET /api/users/whoami`

Returns the token context if present; otherwise 403.
Requires a bearer token even though the route is on the unauthenticated pipeline.
```json
{
  "ok": true,
  "code": 200,
  "data": {
    "user_id": "c0c7d53e-7a76-4f4f-9f1e-e5a0f6e9c8b1",
    "session_id": "c2f8c1aa-9a3e-4d58-9f3b-e7f0c2c94a10",
    "ip_address": "127.0.0.1",
    "valid_only_for_ip": false,
    "user_roles": ["user"],
    "expires_at": "2025-01-01T12:00:00Z",
    "terms_of_service": 2,
    "privacy_policy": 1
  }
}
```

### Password Reset
- `POST /api/users/:id/reset_password` (id or username) — issues a reset token and emails it.
- `PUT /api/users/:id/reset_password/:token`
- `PUT /api/users/reset_password/:token`

Body for token exchange:
```json
{ "new_password": "newpassword123" }
```

Success: `{"ok": true, "code": 200}`. Invalid/missing/expired tokens return 401 with an error message.
Notes: Reset email requests return 404 when the user is unknown and 429 when rate limited.

### Health Checks
- `GET /health_check/liveness`
- `GET /health_check/readiness`

---

## Authenticated User Endpoints
Bearer token required; ToS/Privacy acceptance may be enforced (461/462) depending on deployment settings.

### Current User
- `GET /api/users/current` (alias `GET /api/users/me`, deprecated)
- `GET /api/users/:id` (owner or admin)

Returns full user data including addresses and phone numbers when loaded.

### Update User
`PUT /api/users/:id`

Body may include profile fields and flags:
```json
{
  "user": {
    "first_name": "Jane",
    "last_name": "Doe",
    "display_name": "Jane Q. Doe",
    "nick_name": "JD",
    "gender": "Cis Female",
    "race": ["White"],
    "ethnicity": "Not Hispanic or Latinx",
    "height": 167,
    "weight": 63,
    "birthday": "1995-01-01",
    "password": "newpassword123",
    "accept_tos": true,
    "accept_privacy_policy": true,
    "approved_ips": ["1.2.3.4"],
    "preferences": {
      "theme": "dark",
      "display_name_pref": "full_name",
      "display_middle_initial_only": true
    },
    "custom_attrs": { "plan": "pro" },
    "addresses": [{
      "name": "Home",
      "line_1": "123 Main St",
      "line_2": "Apt 5",
      "city": "Anytown",
      "state": "CA",
      "postal": "12345",
      "country": "US",
      "primary": true
    }],
    "phone_numbers": [{
      "number": "+14155550123",
      "primary": true
    }]
  }
}
```
- `user` is required; any fields not supplied remain unchanged. Gender uses an enumerated list (Cis/Cisgender, Trans*, Non-binary, Two-spirit, etc.); race and ethnicity are enumerated as above.
- `user_id` in the path may be the UUID, username, or `current` (for nested routes). Addresses and phone numbers use the same shapes as their dedicated endpoints.

Example:
```bash
curl -X PUT \
  -H "Authorization: Bearer ${api_token}" \
  -H "Content-Type: application/json" \
  -d '{"user":{"first_name":"Jane","accept_tos":true,"accept_privacy_policy":true}}' \
  http://localhost:4000/api/users/current
```

Response (`200 OK`):
```json
{
  "ok": true,
  "code": 200,
  "data": {
    "id": "c0c7d53e-7a76-4f4f-9f1e-e5a0f6e9c8b1",
    "first_name": "Jane",
    "latest_tos_accept_ver": 2,
    "latest_pp_accept_ver": 1,
    "roles": ["user"]
  }
}
```

### Delete User
`DELETE /api/users/:id`

Response: `204 No Content` (user record is anonymized)

### Sessions (User)
- `GET /api/sessions/active` — active sessions for the current token (paginated)
- `GET /api/sessions/current`
- `PUT /api/sessions/current/extend` — body `{ "expire_in_seconds": 3600 }`
- `PUT /api/users/:user_id/sessions/current/extend` — owner/admin alias of the above
- `DELETE /api/sessions/current`
- `GET /api/users/:user_id/sessions` — paginated, owner or admin
- `GET /api/users/:user_id/sessions/:id`
- `PUT /api/users/:user_id/sessions/:id/extend` — same body as above
- `DELETE /api/users/:user_id/sessions/:id`
- `DELETE /api/users/:user_id/sessions` — revoke all active sessions for the user
- `GET /api/users/:user_id/sessions/active` — active only

Notes:
- Extension endpoints return `403 SessionRevokedOrExpired` when the session is no longer valid.
- `DELETE /api/users/:user_id/sessions` responds with `{status, num_revoked, message}` so you can confirm how many tokens were revoked.
- `page_num` / `page_size` apply to list endpoints; tokens are only returned on session creation, not on reads.

Examples:
- List sessions (paginated):
  ```bash
  curl -H "Authorization: Bearer ${api_token}" \
    "http://localhost:4000/api/users/current/sessions?page_num=0&page_size=5"
  ```
  Response:
  ```json
  { "ok": true, "code": 200, "page_num": 0, "page_size": 5, "data": [
    { "id": "sess-1", "user_id": "...", "expires_at": "2025-01-01T12:00:00Z", "revoked_at": null, "is_valid": true }
  ]}
  ```
- Extend current session:
  ```bash
  curl -X PUT \
    -H "Authorization: Bearer ${api_token}" \
    -H "Content-Type: application/json" \
    -d '{"expire_in_seconds":3600}' \
    http://localhost:4000/api/sessions/current/extend
  ```
- Revoke a session:
  ```bash
  curl -X DELETE -H "Authorization: Bearer ${api_token}" \
    http://localhost:4000/api/users/current/sessions/sess-1
  ```

### Session Extensions
- `GET /api/sessions/:session_id/extensions`
- `GET /api/session_extensions/:id`

Each record includes `old_expires_at`, `new_expires_at`, `extended_by_seconds`, and auditing fields. Lists are ordered newest first. Only the session owner or an admin may view these records; others receive 401/403.

Example list:
```bash
curl -H "Authorization: Bearer ${api_token}" \
  "http://localhost:4000/api/sessions/${session_id}/extensions?page_num=0&page_size=5"
```

Response:
```json
{
  "ok": true,
  "code": 200,
  "page_num": 0,
  "page_size": 5,
  "data": [
    {
      "id": "ext-1",
      "old_expires_at": "2025-01-01T12:00:00Z",
      "new_expires_at": "2025-01-02T12:00:00Z",
      "extended_by_seconds": 86400,
      "extended_by_session": "sess-1",
      "extended_by_user": "user-1",
      "session_id": "sess-1",
      "user_id": "user-1"
    }
  ]
}
```

### Contact Information
All routes require the owner or an admin.

**Phone Numbers** (`/api/users/:user_id/phone_numbers`)
- `GET /` — list
- `GET /:id`
- `POST /` — body `{ "phone_number": { "number": "+1234567890", "primary": true } }`
- `PUT /:id`
- `DELETE /:id`

Create example:
```bash
curl -X POST \
  -H "Authorization: Bearer ${api_token}" \
  -H "Content-Type: application/json" \
  -d '{"phone_number":{"number":"+14155550123","primary":true}}' \
  http://localhost:4000/api/users/current/phone_numbers
```

Response (`201 Created`):
```json
{ "ok": true, "data": { "id": "ph-1", "user_id": "user-1", "number": "+14155550123", "primary": true } }
```

**Addresses** (`/api/users/:user_id/addresses`)
- `GET /`
- `GET /:id`
- `POST /` — body `{ "address": { "name": "Home", "line_1": "123 Main St", "line_2": "Apt 5", "city": "Anytown", "state": "CA", "postal": "12345", "country": "US", "primary": true } }`
- `PUT /:id`
- `DELETE /:id`

Create example:
```bash
curl -X POST \
  -H "Authorization: Bearer ${api_token}" \
  -H "Content-Type: application/json" \
  -d '{"address":{"name":"Home","line_1":"123 Main St","line_2":"Apt 5","city":"Anytown","state":"CA","postal":"12345","country":"US","primary":true}}' \
  http://localhost:4000/api/users/current/addresses
```

Response (`201 Created`):
```json
{ "ok": true, "data": { "id": "addr-1", "user_id": "user-1", "name": "Home", "city": "Anytown", "state": "CA" } }
```

Address payloads require `line_2` in this API. Both addresses and phone numbers include `primary` flags and surface `verified_at` timestamps when present.

### Logs (User)
- `GET /api/logs` — paginated logs for the authenticated user
- `GET /api/logs/:id` — only if you own the log or are admin
- `GET /api/users/:user_id/logs` — owner/admin alias to fetch logs for a specific user

Example:
```bash
curl -H "Authorization: Bearer ${api_token}" \
  "http://localhost:4000/api/logs?page_num=0&page_size=10"
```

Response:
```json
{
  "ok": true,
  "data": [
    { "id": "log-1", "verb": "POST", "type": "sessions", "what": "#SessionController.create/2", "when": "2024-12-16T12:00:00Z" }
  ],
  "page_num": 0,
  "page_size": 10
}
```
Log payloads use `type` (`users`|`sessions`) and HTTP `verb` (`GET`|`POST`|`PUT`|`DELETE`). All list endpoints take `page_num`/`page_size`.

---

## Admin Endpoints
Require an admin token (`roles` includes `"admin"`). These routes skip ToS/Privacy plugs.

### Users
- `GET /api/admin/users` — paginated list (`page_num`/`page_size`)
- `PUT /api/admin/users/:id` — update any user (email/username/password, roles including `moderator`, `reset_password` flag, approved IPs, preferences, addresses, phone numbers)
- `PUT /api/admin/users/:id/lock`
- `PUT /api/admin/users/:id/unlock`

Examples:
- List users:
  ```bash
  curl -H "Authorization: Bearer ${admin_token}" \
    "http://localhost:4000/api/admin/users?page_num=0&page_size=10"
  ```
- Lock a user:
  ```bash
  curl -X PUT -H "Authorization: Bearer ${admin_token}" \
    http://localhost:4000/api/admin/users/c0c7d53e-7a76-4f4f-9f1e-e5a0f6e9c8b1/lock
  ```
- Update roles / force reset:
  ```bash
  curl -X PUT \
    -H "Authorization: Bearer ${admin_token}" \
    -H "Content-Type: application/json" \
    -d '{"user":{"roles":["admin","moderator"],"reset_password":true,"approved_ips":["1.2.3.4"]}}' \
    http://localhost:4000/api/admin/users/c0c7d53e-7a76-4f4f-9f1e-e5a0f6e9c8b1
  ```

### Password Reset (Admin)
- `POST /api/admin/users/:id/reset_password` — issue reset token (returns token + expiry)
- `PUT /api/admin/users/:id/reset_password/:token`
- `PUT /api/admin/users/reset_password/:token`

Issue token example:
```bash
curl -X POST -H "Authorization: Bearer ${admin_token}" \
  http://localhost:4000/api/admin/users/c0c7d53e-7a76-4f4f-9f1e-e5a0f6e9c8b1/reset_password
```
Response:
```json
{
  "ok": true,
  "code": 200,
  "data": {
    "password_reset_token": "abcd1234",
    "password_reset_token_expires_at": "2025-01-02T12:00:00Z"
  }
}
```

### Sessions (Admin)
- `GET /api/admin/sessions` — paginated
- `DELETE /api/admin/sessions/:id`

### Logs (Admin)
- `GET /api/admin/logs` — all logs, paginated
- `GET /api/admin/logs/:id`
- `GET /api/admin/logs/users/:user_id` — actions performed by user
- `GET /api/admin/logs/sessions/:session_id` — actions performed by session
- `GET /api/admin/logs/who/:user_id` — actions that targeted the user

Example (by user):
```bash
curl -H "Authorization: Bearer ${admin_token}" \
  "http://localhost:4000/api/admin/logs/users/c0c7d53e-7a76-4f4f-9f1e-e5a0f6e9c8b1?page_size=20"
```

---

## Field Notes
- Path parameters `:id` for users accept either UUID or username; nested `user_id` routes also allow `current`.
- Roles supported: `user`, `admin`, `moderator`.
- User payloads include `email_verified`, `locked_at/locked_by`, `tos_accepted` / `privacy_policy_accepted`, and acceptance event arrays; `token_expired` may appear on error payloads.
- Gender is validated against the enumerated list in the OpenAPI spec (covers cis/trans/non-binary variants). Race is one of the five US census values; ethnicity is Hispanic/Not Hispanic.
- Addresses require `line_2`; address/phone responses include `primary` and `verified_at` when set.
- Session creation honors `valid_only_for_ip` and `valid_only_for_approved_ips`; if a user has `approved_ips`, login is constrained to those addresses even when the flag is false.
- Session defaults: expires in 7 days, extendable window 28 days, max single extension 7 days. An absolute cap is configurable; lists of session extensions are ordered newest first.
- Minimum password length defaults to 6 characters (`MIN_PASSWORD_LENGTH`).

For quick examples, see `scripts/curl/` in the repo.
