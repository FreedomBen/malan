# Malan HTTP API

Malan is a Phoenix 1.8 (app version `0.1.0`) authentication service that issues API tokens and manages users, sessions, and audit logs.

## Base URLs
- Development: `http://localhost:4000`
- Staging: `https://malan-staging.ameelio.xyz` (also served via `https://accounts.ameelio.xyz`)
- Production: `https://malan.ameelio.org` (alias `https://accounts.ameelio.org`)

## Authentication & Tokens
- Pass the token returned from **POST /api/sessions** as `Authorization: Bearer <token>`.
- Most `/api` routes require a token; unauthenticated exceptions are called out below.
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
- 401 Unauthorized (authenticated but not allowed)
- 403 Forbidden (missing/invalid token or expired session)
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
    "custom_attrs": { "source": "signup-form" },
    "approved_ips": ["1.2.3.4"]
  }
}
```

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

### Create Session (Login)
`POST /api/sessions`

Body:
```json
{
  "session": {
    "username": "user@example.com",
    "password": "password123",
    "expires_in_seconds": 3600,               // optional, default 7 days
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

### Who Am I
`GET /api/users/whoami`

Returns the token context if present; otherwise 403.
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
    "password": "newpassword123",
    "accept_tos": true,
    "accept_privacy_policy": true,
    "approved_ips": ["1.2.3.4"],
    "custom_attrs": { "plan": "pro" }
  }
}
```

### Delete User
`DELETE /api/users/:id`

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

### Session Extensions
- `GET /api/sessions/:session_id/extensions`
- `GET /api/session_extensions/:id`

Each record includes `old_expires_at`, `new_expires_at`, `extended_by_seconds`, and auditing fields.

### Contact Information
All routes require the owner or an admin.

**Phone Numbers** (`/api/users/:user_id/phone_numbers`)
- `GET /` — list
- `GET /:id`
- `POST /` — body `{ "phone_number": { "number": "+1234567890", "primary": true } }`
- `PUT /:id`
- `DELETE /:id`

**Addresses** (`/api/users/:user_id/addresses`)
- `GET /`
- `GET /:id`
- `POST /` — body `{ "address": { "name": "Home", "line_1": "123 Main St", "city": "Anytown", "state": "CA", "postal": "12345", "country": "US" } }`
- `PUT /:id`
- `DELETE /:id`

### Logs (User)
- `GET /api/logs` — paginated logs for the authenticated user
- `GET /api/logs/:id` — only if you own the log or are admin
- `GET /api/users/:user_id/logs` — owner/admin alias to fetch logs for a specific user

---

## Admin Endpoints
Require an admin token (`roles` includes `"admin"`). These routes skip ToS/Privacy plugs.

### Users
- `GET /api/admin/users` — paginated list
- `PUT /api/admin/users/:id` — update any user (roles, locks, password, etc.)
- `PUT /api/admin/users/:id/lock`
- `PUT /api/admin/users/:id/unlock`

### Password Reset (Admin)
- `POST /api/admin/users/:id/reset_password` — issue reset token
- `PUT /api/admin/users/:id/reset_password/:token`
- `PUT /api/admin/users/reset_password/:token`

### Sessions (Admin)
- `GET /api/admin/sessions` — paginated
- `DELETE /api/admin/sessions/:id`

### Logs (Admin)
- `GET /api/admin/logs` — all logs, paginated
- `GET /api/admin/logs/:id`
- `GET /api/admin/logs/users/:user_id` — actions performed by user
- `GET /api/admin/logs/sessions/:session_id` — actions performed by session
- `GET /api/admin/logs/who/:user_id` — actions that targeted the user

---

## Field Notes
- Path parameters `:id` for users accept either UUID or username.
- Session creation honors `valid_only_for_ip` and `valid_only_for_approved_ips`; if enabled, token usage is restricted accordingly.
- If a user has `approved_ips` set, login is only allowed from those IPs even if `valid_only_for_approved_ips` is false.
- Default session expiry is 7 days; default per-extension limit is 7 days; absolute extension cap is 90 days unless overridden by configuration.
- Minimum password length defaults to 6 characters (`MIN_PASSWORD_LENGTH`).

For quick examples, see `scripts/curl/` in the repo.
