# Malan Authentication Service API Documentation

Malan is a comprehensive authentication service providing user management, session handling, and administrative features. This documentation covers all available API endpoints with examples.

## Base URL

- Development: `http://localhost:4000`
- Staging: `https://malan-staging.ameelio.org`
- Production: `https://malan.ameelio.org`

## Authentication

Most endpoints require an API token passed as a Bearer token in the Authorization header:

```bash
Authorization: Bearer YOUR_API_TOKEN
```

## Response Format

All responses follow a consistent JSON structure:

```json
{
  "data": { /* response data */ },
  "message": "Success message",
  "status": "success"
}
```

Error responses:

```json
{
  "errors": { /* field-specific errors */ },
  "message": "Error message",
  "status": "error"
}
```

## HTTP Status Codes

- `200` - OK
- `201` - Created
- `204` - No Content
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `422` - Unprocessable Entity
- `500` - Internal Server Error

---

## Authentication Endpoints

### Create User

Creates a new user account.

**Endpoint:** `POST /api/users`  
**Authentication:** None required  

**Request Body:**
```json
{
  "user": {
    "email": "user@example.com",
    "username": "username",
    "password": "password123",
    "first_name": "John",
    "last_name": "Doe"
  }
}
```

**Example:**
```bash
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"user":{"email":"user@example.com","username":"username","password":"password123","first_name":"John","last_name":"Doe"}}' \
  http://localhost:4000/api/users
```

**Response (201 Created):**
```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "user@example.com",
    "username": "username",
    "first_name": "John",
    "last_name": "Doe",
    "roles": ["user"],
    "inserted_at": "2023-01-01T00:00:00Z",
    "updated_at": "2023-01-01T00:00:00Z"
  }
}
```

### Create Session (Login)

Authenticates a user and returns an API token.

**Endpoint:** `POST /api/sessions`  
**Authentication:** None required  

**Request Body:**
```json
{
  "session": {
    "username": "username",
    "password": "password123",
    "expires_in_seconds": 3600,
    "never_expires": false
  }
}
```

**Parameters:**
- `username` (required) - Username or email address
- `password` (required) - User password
- `expires_in_seconds` (optional) - Token expiration time in seconds
- `never_expires` (optional) - Set to `true` for permanent tokens

**Example:**
```bash
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"session":{"username":"username","password":"password123"}}' \
  http://localhost:4000/api/sessions
```

**Forever Token Example:**
```bash
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"session":{"username":"username","password":"password123","never_expires":true}}' \
  http://localhost:4000/api/sessions
```

**Response (201 Created):**
```json
{
  "data": {
    "api_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_at": "2023-01-01T01:00:00Z",
    "user_id": "123e4567-e89b-12d3-a456-426614174000"
  }
}
```

### Check Authentication Status

Returns the current user's information if authenticated.

**Endpoint:** `GET /api/users/whoami`  
**Authentication:** None required (but returns user info if token provided)  

**Example:**
```bash
# Get current user info
api_token="$(curl --request POST --header "Accept: application/json" --header "Content-Type: application/json" --data '{"session":{"username":"username","password":"password123"}}' http://localhost:4000/api/sessions | jq -r .data.api_token)"

curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/whoami
```

**Response (200 OK) when authenticated:**
```json
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "user@example.com",
    "username": "username",
    "first_name": "John",
    "last_name": "Doe",
    "roles": ["user"]
  }
}
```

**Response (200 OK) when not authenticated:**
```json
{
  "data": null
}
```

---

## User Management Endpoints

### Get Current User

Returns detailed information about the authenticated user.

**Endpoint:** `GET /api/users/current`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/current
```

### Get User by ID

Returns information about a specific user. Users can only access their own data unless they're an admin.

**Endpoint:** `GET /api/users/:id`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/123e4567-e89b-12d3-a456-426614174000
```

### Update User

Updates user information. Users can only update their own data unless they're an admin.

**Endpoint:** `PUT /api/users/:id`  
**Authentication:** Required  

**Request Body:**
```json
{
  "user": {
    "first_name": "Jane",
    "last_name": "Smith",
    "email": "newemail@example.com"
  }
}
```

**Example:**
```bash
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data '{"user":{"first_name":"Jane","last_name":"Smith"}}' \
  http://localhost:4000/api/users/123e4567-e89b-12d3-a456-426614174000
```

### Change Password

Updates a user's password.

**Endpoint:** `PUT /api/users/:id`  
**Authentication:** Required  

**Request Body:**
```json
{
  "user": {
    "password": "newpassword123"
  }
}
```

**Example:**
```bash
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data '{"user":{"password":"newpassword123"}}' \
  http://localhost:4000/api/users/123e4567-e89b-12d3-a456-426614174000
```

### Delete User

Deletes a user account. Users can only delete their own account unless they're an admin.

**Endpoint:** `DELETE /api/users/:id`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/123e4567-e89b-12d3-a456-426614174000
```

---

## Session Management Endpoints

### Get Current Session

Returns information about the current session.

**Endpoint:** `GET /api/sessions/current`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/sessions/current
```

### Get Active Sessions

Returns all active sessions for the authenticated user.

**Endpoint:** `GET /api/sessions/active`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/sessions/active
```

### Extend Current Session

Extends the expiration time of the current session.

**Endpoint:** `PUT /api/sessions/current/extend`  
**Authentication:** Required  

**Request Body:**
```json
{
  "expires_in_seconds": 3600
}
```

**Example:**
```bash
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  --data '{"expires_in_seconds": 3600}' \
  http://localhost:4000/api/sessions/current/extend
```

### Delete Current Session (Logout)

Deletes the current session, effectively logging out the user.

**Endpoint:** `DELETE /api/sessions/current`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/sessions/current
```

### Get User Sessions

Returns all sessions for a specific user. Users can only access their own sessions unless they're an admin.

**Endpoint:** `GET /api/users/:user_id/sessions`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/123e4567-e89b-12d3-a456-426614174000/sessions
```

### Delete User Session

Deletes a specific session for a user.

**Endpoint:** `DELETE /api/users/:user_id/sessions/:id`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/123e4567-e89b-12d3-a456-426614174000/sessions/456e7890-e89b-12d3-a456-426614174000
```

### Delete All User Sessions

Deletes all sessions for a user.

**Endpoint:** `DELETE /api/users/:user_id/sessions`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/users/123e4567-e89b-12d3-a456-426614174000/sessions
```

---

## Password Reset Endpoints

### Request Password Reset Token

Requests a password reset token for a user.

**Endpoint:** `POST /api/users/:id/reset_password`  
**Authentication:** None required  

**Request Body:**
```json
{
  "new_password": "newpassword123"
}
```

**Example:**
```bash
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"new_password":"newpassword123"}' \
  http://localhost:4000/api/users/username/reset_password
```

### Use Password Reset Token

Uses a password reset token to set a new password.

**Endpoint:** `PUT /api/users/reset_password/:token`  
**Authentication:** None required  

**Request Body:**
```json
{
  "new_password": "newpassword123"
}
```

**Example:**
```bash
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"new_password":"newpassword123"}' \
  http://localhost:4000/api/users/reset_password/abc123token
```

---

## Contact Information Endpoints

### Phone Numbers

#### List User Phone Numbers

**Endpoint:** `GET /api/users/:user_id/phone_numbers`  
**Authentication:** Required (owner or admin)  

#### Get Phone Number

**Endpoint:** `GET /api/users/:user_id/phone_numbers/:id`  
**Authentication:** Required (owner or admin)  

#### Create Phone Number

**Endpoint:** `POST /api/users/:user_id/phone_numbers`  
**Authentication:** Required (owner or admin)  

**Request Body:**
```json
{
  "phone_number": {
    "number": "+1234567890",
    "type": "mobile"
  }
}
```

#### Update Phone Number

**Endpoint:** `PUT /api/users/:user_id/phone_numbers/:id`  
**Authentication:** Required (owner or admin)  

#### Delete Phone Number

**Endpoint:** `DELETE /api/users/:user_id/phone_numbers/:id`  
**Authentication:** Required (owner or admin)  

### Addresses

#### List User Addresses

**Endpoint:** `GET /api/users/:user_id/addresses`  
**Authentication:** Required (owner or admin)  

#### Get Address

**Endpoint:** `GET /api/users/:user_id/addresses/:id`  
**Authentication:** Required (owner or admin)  

#### Create Address

**Endpoint:** `POST /api/users/:user_id/addresses`  
**Authentication:** Required (owner or admin)  

**Request Body:**
```json
{
  "address": {
    "street": "123 Main St",
    "city": "Anytown",
    "state": "CA",
    "zip": "12345",
    "country": "US"
  }
}
```

#### Update Address

**Endpoint:** `PUT /api/users/:user_id/addresses/:id`  
**Authentication:** Required (owner or admin)  

#### Delete Address

**Endpoint:** `DELETE /api/users/:user_id/addresses/:id`  
**Authentication:** Required (owner or admin)  

---

## Audit Log Endpoints

### Get User Logs

Returns audit logs for the authenticated user.

**Endpoint:** `GET /api/logs`  
**Authentication:** Required  

**Query Parameters:**
- `limit` - Number of logs to return (default: 50)
- `offset` - Number of logs to skip (default: 0)

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  "http://localhost:4000/api/logs?limit=10&offset=0"
```

### Get Specific Log

Returns a specific audit log entry.

**Endpoint:** `GET /api/logs/:id`  
**Authentication:** Required  

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${api_token}" \
  http://localhost:4000/api/logs/789e0123-e89b-12d3-a456-426614174000
```

---

## Administrative Endpoints

All administrative endpoints require admin privileges.

### List All Users

**Endpoint:** `GET /api/admin/users`  
**Authentication:** Required (admin)  

**Query Parameters:**
- `limit` - Number of users to return
- `offset` - Number of users to skip

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${admin_token}" \
  "http://localhost:4000/api/admin/users?limit=10&offset=0"
```

### Admin Update User

Allows admins to update any user, including roles and administrative fields.

**Endpoint:** `PUT /api/admin/users/:id`  
**Authentication:** Required (admin)  

**Request Body:**
```json
{
  "user": {
    "roles": ["admin", "user"],
    "locked_at": null,
    "password": "newpassword123"
  }
}
```

**Example:**
```bash
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${admin_token}" \
  --data '{"user":{"roles":["admin","user"]}}' \
  http://localhost:4000/api/admin/users/123e4567-e89b-12d3-a456-426614174000
```

### Lock User

Locks a user account, preventing login.

**Endpoint:** `PUT /api/admin/users/:id/lock`  
**Authentication:** Required (admin)  

**Example:**
```bash
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${admin_token}" \
  http://localhost:4000/api/admin/users/123e4567-e89b-12d3-a456-426614174000/lock
```

### Unlock User

Unlocks a user account.

**Endpoint:** `PUT /api/admin/users/:id/unlock`  
**Authentication:** Required (admin)  

**Example:**
```bash
curl \
  --request PUT \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${admin_token}" \
  http://localhost:4000/api/admin/users/123e4567-e89b-12d3-a456-426614174000/unlock
```

### List All Sessions

**Endpoint:** `GET /api/admin/sessions`  
**Authentication:** Required (admin)  

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${admin_token}" \
  http://localhost:4000/api/admin/sessions
```

### Admin Delete Session

**Endpoint:** `DELETE /api/admin/sessions/:id`  
**Authentication:** Required (admin)  

**Example:**
```bash
curl \
  --request DELETE \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${admin_token}" \
  http://localhost:4000/api/admin/sessions/456e7890-e89b-12d3-a456-426614174000
```

### Admin Reset Password

Allows admins to reset any user's password.

**Endpoint:** `POST /api/admin/users/:id/reset_password`  
**Authentication:** Required (admin)  

### Admin Use Reset Token

**Endpoint:** `PUT /api/admin/users/:id/reset_password/:token`  
**Authentication:** Required (admin)  

### Admin Audit Logs

#### Get All Logs

**Endpoint:** `GET /api/admin/logs`  
**Authentication:** Required (admin)  

**Example:**
```bash
curl \
  --request GET \
  --header "Accept: application/json" \
  --header "Authorization: Bearer ${admin_token}" \
  "http://localhost:4000/api/admin/logs?limit=100&offset=0"
```

#### Get User Logs

**Endpoint:** `GET /api/admin/logs/users/:user_id`  
**Authentication:** Required (admin)  

#### Get Session Logs

**Endpoint:** `GET /api/admin/logs/sessions/:session_id`  
**Authentication:** Required (admin)  

#### Get User Activity

**Endpoint:** `GET /api/admin/logs/who/:user_id`  
**Authentication:** Required (admin)  

---

## Health Check Endpoints

### Liveness Check

**Endpoint:** `GET /health_check/liveness`  
**Authentication:** None required  

**Example:**
```bash
curl http://localhost:4000/health_check/liveness
```

### Readiness Check

**Endpoint:** `GET /health_check/readiness`  
**Authentication:** None required  

**Example:**
```bash
curl http://localhost:4000/health_check/readiness
```

---

## Error Handling

### Common Error Responses

**401 Unauthorized:**
```json
{
  "message": "Unauthorized",
  "status": "error"
}
```

**403 Forbidden:**
```json
{
  "message": "Forbidden",
  "status": "error"
}
```

**422 Validation Error:**
```json
{
  "errors": {
    "email": ["can't be blank"],
    "password": ["is too short (minimum is 8 characters)"]
  },
  "message": "Validation failed",
  "status": "error"
}
```

### Rate Limiting

The API implements rate limiting to prevent abuse. When rate limits are exceeded, you'll receive a `429 Too Many Requests` response.

---

## SDK and Libraries

For TypeScript/JavaScript applications, consider using [libmalan](https://github.com/FreedomBen/libmalan), which provides a convenient wrapper around these API endpoints.

---

## Support

For issues and questions:
- GitHub Issues: [malan repository](https://github.com/FreedomBen/malan/issues)
- Email: Contact the development team

---

*This documentation was generated for Malan Authentication Service v0.1.0*