# Malan Authentication Service

Malan is a basic authentication service that you can drop into your microservice ecosystem, or even use as a base for a new Phoenix project.

## Use Malan

### API Documentation

API documentation is available in [`API_DOCUMENTATION.md`](./API_DOCUMENTATION.md) with a concise map in [`API.md`](./API.md).

To upgrade Swagger UI docs: bump `swagger-ui-dist` in `assets/package.json`, run `cd assets && npm install` (postinstall runs the sync) or `./scripts/sync-swagger-ui.sh`, then start the app and visit `/docs`.

### Basic endpoints you'll use

If using Malan as an authentication service, the most common endpoints are:

1. Create a user: `POST /api/users`
1. Login (get an auth token): `POST /api/sessions`
1. Current user details: `GET /api/users/current`
1. Token status: `GET /api/users/whoami`

### Structuring your app with Malan

There are a couple of different ways to structure your application.  One way to structure your app around Malan is to outsource your user and session model to Malan.  Malan allows you to set an arbitrary JSON blob (called `custom_attrs`) on each user, so you can pack a decent amount of info in there.  The user's API token can be stored in session storage and you can easily use just the token to retrieve the relevant user from Malan.  If the token is expired, revoked, or otherwise invalid then no user will be returned so you can trigger a new login page.

Another common option is to maintain a minimal User table in your app that contains the user's malan ID.  If you have a number of things you want to store then this may be a better approach than jamming everything into `custom_attrs`.

## Run Malan

If you have a clone of this repo, you can start Malan easily using Docker Compose (this builds the image from the local source):

```bash
docker compose up
```

### Adding Malan service to an eco-system

If you are adding Malan to your current application, you can make use of [the example docker-compose file](./docker-compose-example.yml). You will need to add Malan and a Postgres service for Malan to use as its data store.

```yaml
version: "3.9"
services:
  postgres:
    image: 'docker.io/postgres:12.6-alpine'
    volumes:
      - 'pgdata:/var/lib/postgresql/data'  # Use a docker volume for the database files
    environment:
      POSTGRES_USER: 'postgres'
      POSTGRES_PASSWORD: 'postgres'

  malan:
    image: 'docker.io/freedomben/malan:latest'
    ports:
      - "4000:4000"
    environment:
      DB_INIT: 'Yes'
      DB_USERNAME: 'postgres'
      DB_PASSWORD: 'postgres'
      DB_HOSTNAME: 'postgres'
      BIND_ADDR: '0.0.0.0'
    depends_on:
      - 'postgres'

volumes:
  pgdata:
```

### Setting up a local development environment

You'll need to:

#### 1. Install Elixir (and Erlang)

Setup instructions vary by platform.

Fedora, CentOS, or RHEL:

```bash
dnf install -y elixir
```

Ubuntu:

```bash
apt install -y elixir
```

macOS:

```bash
brew install elixir
```

#### 2. Bootstrap build tools

```bash
mix local.hex --force
mix local.rebar --force
# Optional: install the Phoenix project generator that matches mix.exs (phoenix ~> 1.8)
mix archive.install hex phx_new
```

#### 3. Clone this repo

```bash
git clone git@github.com:FreedomBen/malan.git
cd malan
```

#### 4. Start Postgres

Use `docker compose up postgres` or run `scripts/start-postgres.sh` for a quick local instance. The default creds are `postgres/postgres` on host `localhost` unless you override env vars.

#### 5. Install deps, migrate, and seed

```bash
mix setup
```

This alias runs `deps.get`, creates the DB, runs migrations, and seeds baseline data. Rerun it whenever dependencies change.

#### 6. Start the Phoenix server

```bash
mix phx.server
```

Use `iex -S mix phx.server` for an interactive shell or `mix phx.server --no-halt` inside containers.

### Basic development operations

- `mix setup` installs Mix deps and npm deps, creates the dev database, and seeds baseline data. Run it any time dependencies change.
- `mix phx.server` (or `iex -S mix phx.server` if you want an IEx shell) boots the Phoenix app locally on `http://localhost:4000`. Use `mix phx.server --no-halt` when running inside containers.
- `mix test` executes the full Elixir test suite. Target a single file with `mix test test/malan/accounts_test.exs` or a specific test using the `:line` option, e.g. `mix test test/malan/accounts_test.exs:42`.
- `mix credo --strict` enforces the formatting and lint rules used in CI; run it before opening a PR to catch style issues early.
- `mix assets.deploy` compiles and digests static assets when you need a production-ready build (the command outputs to `priv/static`).

## Malan API

The Malan API is a REST interface; see [`API_DOCUMENTATION.md`](./API_DOCUMENTATION.md) for full payloads and [`API.md`](./API.md) for a quick map of routes. Some deployments enforce Terms of Service and Privacy Policy acceptance (HTTP 461/462 if missing); you can opt in by setting `accept_tos` / `accept_privacy_policy` on the user record.

If your client will be in TypeScript, you can also consider using [libmalan](https://github.com/FreedomBen/libmalan), a simple utility package that provides TypeScript methods.

## CI/CD and Deployment

CI/CD is handled by GitHub Actions in `.github/workflows/build-test-deploy.yaml` and the helper scripts under `scripts/`:

- Staging: every push/merge to `main` builds, tests, publishes, and deploys to staging automatically.
- Production: push a tag (e.g., `prod-$(date '+%Y-%m-%d-%H-%M-%S')`) to trigger a production deploy.
- Build/publish/deploy logic lives in `scripts/build-release.sh`, `scripts/push-release.sh`, and `scripts/deploy-release.sh`.

### Configuring PostgreSQL users

You should run the web application as a non-privileged user that cannot run DDL commands, and the migrations as a privileged user who can.

```SQL
CREATE ROLE malan WITH LOGIN PASSWORD '<somepassword>';
GRANT CONNECT ON DATABASE malan_prod TO user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO malan;

ALTER DEFAULT PRIVILEGES FOR ROLE
    malan
  IN SCHEMA
    public
  GRANT
    SELECT, INSERT, UPDATE, DELETE
  ON TABLES TO
    malan;
```

## Helpful links regarding Phoenix

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix


## Audit Logs

Many actions are logged in the audit log.  Whether the action result is success or failure, it is logged.  The data that is sent as part of the request is recorded for later analysis.

Here is a (non comprehensive) list of actions logged:

* Creating a user.  Includes the original creation data except password
* Updating a user.  Includes the changed data
* Locking a user
* Unlocking a user
* Deleting a user
* Requesting a password reset token
* Using a password reset token
* Changing a user password
* Creating a session (aka "logging in")
* Deleting a session (aka "logging out")
* Extending a session

Logs are exposed over the API (`/api/logs` for users, `/api/admin/logs*` for admins). You can also query them directly from the database via `iex` or `psql` if you need ad-hoc analysis (examples below).

NOTE:  In order to optimize the logs table for _writes_, the indexes are minimal.  This means there is a long and beefy table scan for querying.  Keep this in mind if you have a large production table!

### Using psql

1.  Get a shell in a running container.  If using Kubernetes, you can use `kubectl exec`.  Substitute the pod name for a current pod in your environment.  You can list them with `kubectl -n malan-staging get pods`

  ```bash
  $ kubectl -n malan-staging exec -it <valid-pod-name> -- bash
  ```

2.  Start a `psql` shell.  There is a convenient alias in the bashrc already that you can use to connect to the database for that pod:

  ``` bash
  $ psql-malan
  ```

3.  Run your queries.  There are some examples in the next section:

#### Postgres example queries:

Get entire log history for a user with ID `ffa9c147-900b-4813-b738-9b924237fdc7` (Note this could be huge!  Use caution in production)

```SQL
SELECT *
FROM logs
WHERE user_id = 'ffa9c147-900b-4813-b738-9b924237fdc7'
ORDER BY logs.inserted_at DESC;
```

Get 10 most recent logs for a user with ID `ffa9c147-900b-4813-b738-9b924237fdc7`

```SQL
SELECT *
FROM logs
WHERE user_id = 'ffa9c147-900b-4813-b738-9b924237fdc7'
ORDER BY logs.inserted_at DESC
LIMIT 10;
```

Get 10 most recent logs for a user with email address `hello@example.com`

```SQL
SELECT logs.*
FROM logs
JOIN users ON logs.user_id = users.id
WHERE users.email = 'hello@example.com'
ORDER BY logs.inserted_at DESC
LIMIT 10;
```

Get the 10 most recent logs for user with ID `ef886248-32b9-48c1-bd4d-303c1cda1f94` that were "Unauthorized login attempt":

```SQL
SELECT *
FROM logs
WHERE user_id = 'ef886248-32b9-48c1-bd4d-303c1cda1f94'
  AND what LIKE '%Unauthorized%'
ORDER BY inserted_at DESC
LIMIT 10;
```

Get the 10 most recent logs for user email `hello@example.com` that were "Unauthorized login attempt":

```SQL
SELECT logs.*
FROM logs
JOIN users ON logs.user_id = users.id
WHERE users.email = 'hello@example.com'
  AND logs.what LIKE '%Unauthorized%'
ORDER BY logs.inserted_at DESC
LIMIT 10;
```

## Frequently Asked Questions (FAQs)

### 1.  Where does the name "malan" come from?

It's an extremely nerdy name based [on a character from the Stormlight Archive series](https://coppermind.net/wiki/Malan) by Brandon Sanderson.
