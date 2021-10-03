# API for Malan

Most endpoints will use an API token which should be passed as an Authorization: Bearer token

## Summary table:

```
  POST    /api/users
  POST    /api/sessions
  GET     /api/users/whoami
  GET     /api/users/:id
  PATCH   /api/users/:id
  PUT     /api/users/:id
  DELETE  /api/users/:id
  GET     /api/users/:user_id/sessions
  GET     /api/users/:user_id/sessions/:id
  DELETE  /api/users/:user_id/sessions/:id
  GET     /api/admin/users
  PUT     /api/admin/users/:id
  GET     /api/admin/sessions
  DELETE  /api/admin/sessions/:id
```

## Create User

POST /api/users

```
{
  user: {
    email: string,
    username: string,
    password: string,
    first_name: string,
    last_name: string
  }
}
```

Example:

```
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data "{\"user\":{\"email\":\"${NEW_EMAIL}\",\"username\":\"${NEW_USERNAME}\",\"password\":\"${NEW_PASSWORD}\",\"first_name\":\"${NEW_FIRST_NAME}\",\"last_name\":\"${NEW_LAST_NAME}\"}}" \
  http://localhost:4000/api/users/
```

Returns user:

201 - Created
401 - Invalid credentials
403 - Unauthorized (not logged in)
422 - Validation failed.  Check properties

## Log in / Create Session

POST /api/sessions

```
{
  session: {
    username: string,
    password: string
  }
}
```

Returns: api_token:

201 - Created
401 - Invalid credentials
403 - Unauthorized (not logged in)
422 - Validation failed.  Check properties

Example:

```
curl \
  --request POST \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --data '{"session":{"email":"root@example.com","username":"root","password":"password10"}}' \
  http://localhost:4000/api/sessions/ \
 | jq -r '.data.api_token'
```

## Get user's info



## Log out / Delete Session

DELETE /api/users/:user_id/sessions/:session_id

```
{

}
```

Returns:

200 - Logged out success
401 - Not the session owner
403 - Unauthorized (not logged in)


## User
