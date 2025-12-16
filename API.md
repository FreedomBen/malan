# API Quick Reference

This is a condensed map of Malan's HTTP API. See `API_DOCUMENTATION.md` for request/response examples and field descriptions.

## Public (no token)
- `POST /api/users` — create user
- `POST /api/sessions` — login (returns `api_token`)
- `GET /api/users/whoami` — token context if provided
- `POST /api/users/:id/reset_password` — issue reset token (id or username)
- `PUT /api/users/:id/reset_password/:token`
- `PUT /api/users/reset_password/:token`
- `GET /health_check/liveness`
- `GET /health_check/readiness`

## Authenticated User Routes
Token required; ToS/Privacy acceptance may be enforced (461/462) depending on deployment config.

- `GET /api/users/current` (alias `/users/me`, deprecated)
- `GET /api/users/:id`
- `PUT/PATCH /api/users/:id`
- `DELETE /api/users/:id`
- `GET /api/logs` — your logs (paginated)
- `GET /api/logs/:id` — if owner or admin

### Sessions
- `GET /api/sessions/active`
- `GET /api/sessions/current`
- `PUT /api/sessions/current/extend` — body `{ "expire_in_seconds": <secs> }`
- `PUT /api/users/:user_id/sessions/current/extend` — owner/admin alias of the above
- `DELETE /api/sessions/current`
- `GET /api/users/:user_id/sessions` (paginated)
- `GET /api/users/:user_id/sessions/:id`
- `PUT /api/users/:user_id/sessions/:id/extend`
- `DELETE /api/users/:user_id/sessions/:id`
- `DELETE /api/users/:user_id/sessions` — revoke all active
- `GET /api/users/:user_id/sessions/active`

### Logs
- `GET /api/logs` — current user’s logs (paginated)
- `GET /api/logs/:id` — if owner or admin
- `GET /api/users/:user_id/logs` — owner/admin alias

### Session Extensions
- `GET /api/sessions/:session_id/extensions`
- `GET /api/session_extensions/:id`

### Contact Info
- Phone numbers: `GET/POST /api/users/:user_id/phone_numbers`, `GET/PUT/DELETE /api/users/:user_id/phone_numbers/:id`
- Addresses: `GET/POST /api/users/:user_id/addresses`, `GET/PUT/DELETE /api/users/:user_id/addresses/:id`

## Admin Routes (admin role required)
- `GET /api/admin/users`
- `PUT /api/admin/users/:id`
- `PUT /api/admin/users/:id/lock`
- `PUT /api/admin/users/:id/unlock`
- `POST /api/admin/users/:id/reset_password`
- `PUT /api/admin/users/:id/reset_password/:token`
- `PUT /api/admin/users/reset_password/:token`
- `GET /api/admin/sessions`
- `DELETE /api/admin/sessions/:id`
- Logs: `GET /api/admin/logs`, `/api/admin/logs/:id`, `/api/admin/logs/users/:user_id`, `/api/admin/logs/sessions/:session_id`, `/api/admin/logs/who/:user_id`

## Handy Payloads
- Login: `{"session":{"username":"you@example.com","password":"...","expires_in_seconds":3600}}`
- Extend current session: `{"expire_in_seconds":3600}`
- Accept ToS/Privacy: `{"user":{"accept_tos":true,"accept_privacy_policy":true}}` (PUT `/api/users/:id`)
