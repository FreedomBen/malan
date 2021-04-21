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
  WS      /socket/websocket
```

## Create User

POST /api/users

-H Authorization: Bearer token


## Log in / Create Session

POST /api/sessions

{
  session: {
    username: string,
    password: string
  }
}

Returns: api_token:

201 - session
401 - invalid_credentials

## Get user's info



## Log out / Delete Session

DELETE /api/users/:user_id/sessions/:session_id

{

}

Returns:

200 - Logged out success
401 - Not the session owner
403 - Unauthorized (not logged in)


## User
