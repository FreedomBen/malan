# API for Malan

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

## Log out / Delete Session

DELETE /api/users/:user_id/sessions/:session_id

{

}

Returns:

200 - Logged out success
401 - Not the session owner
403 - Unauthorized (not logged in)


## User
