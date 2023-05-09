# Malan Authentication Service

Malan is a basic authentication service that you can drop into you microservice ecosystem, or even use as a base for a new Phoenix project.

## Use Malan

### Basic endpoints you'll use

If using Malan as an authentication service, there are 3 main endpoints you'll use:

1.  Create a user:  `POST /api/users`
1.  Login (get an auth token) for a user:  `POST /api/sessions`
1.  Check auth status:  `GET /api/users/whoami`

### Structuring your app with Malan

There are a couple of different ways to structure your application.  One way to structure your app around Malan is to outsource your user and session model to Malan.  Malan allows you to set an arbitrary JSON blob (called `custom_attrs`) on each user, so you can pack a decent amount of info in there.  The user's API token can be stored in session storage and you can easily use just the token to retrieve the relevant user from Malan.  If the token is expired, revoked, or otherwise invalid then no user will be returned so you can trigger a new login page.

Another common option is to maintain a minimal User table in your app that contains the user's malan ID.  If you have a number of things you want to store then this may be a better approach than jamming everything into `custom_attrs`.

## Run Malan

If you have a clone of this repo, you can start Malan easily using Docker Compose:

```bash
docker-compose up
```

### Adding Malan service to an eco-system

If you are adding Malan to your current application, you can make use of [the example docker-compose file](https://github.com/FreedomBen/malan/blob/main/docker-compose-example.yml).  You will need to add Malan, and a Postgres for Malan to use as its data store.

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
    image: 'docker.io/freedomben/malan-dev:latest'
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

#### 1.  Install Elixir and Mix

Setup instructions vary by platform.

Fedora, CentOS, or RHEL:

```bash
dnf install -y elixir
```

Ubuntu:

```bash
apt install -y elixir
```

Mac OS:

```bash
brew install elixir
```

#### 2.  Setup Hex

```bash
mix local.hex
```

If you need to install Phoenix separately, you can do so with hex:

```bash
mix archive.install hex phx_new 1.5.8
```

#### 3.  Clone this repo and install dependencies

```bash
git clone https://github.com/freedomben/malan.git \
cd malan
mix deps.get
```

#### 4.  Run migrations

Note:  You'll need Postgres to be running before completing this step.   If you are not using docker-compose, you can make use of the script at `script/start-postgres.sh` to quickly get a database running.

```bash
mix ecto.setup
```

#### 5.  Start the Phoenix server

```bash
mix phx.server
```

## Malan API

The Malan API is a pretty standard REST interface.  For details, please visit [API.md](https://github.com/FreedomBen/malan/blob/main/API.md).

If your client will be in TypeScript, you can also consider using [libmalan](https://github.com/FreedomBen/libmalan), a simple utility package that provides TypeScript methods.

## CI/CD and Deployment

Staging deploys automatically upon merge to main.  Prod deploys after being tagged:

```bash
git tag "prod-$(date '+%Y-%m-%d-%H-%M-%S')"
git push --tags
```

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


## CI/CD

The CI/CD system utilizes Github Actions to run automated builds, tests, and deployments to all environments.

### Environments

#### Prod

The Production environment is where the production instances of the application are running.  Deployments to Production are fully automated but are not automatic.  Deploys to Production are triggered using git tags.

#### Staging

The staging environment.  Staging is typically a small change ahead of production to allow for testing in a "prod-like" environment

All commits, merges, and tags added to the `main` branch will automatically trigger a deployment to staging.

### The pieces to CI/CD in this repo are these

1.  `.github/workflows/build-test-deploy.yaml`:  This yaml file contains the Github-specific configuration.  It tells Github Actions how to run the build, push the image, run the tests, and deploy the change.
1.  `scripts/build-release.sh:  This script contains the instructions that build the release into an image.
1.  `scripts/push-release.sh:  This script contains the instructions that push the application image to the registry.
1.  `scripts/deploy-release.sh:  This script contains the instructions that deploy the change to Kubernetes.  It contains the bulk of the CD logic.


## Frequently Asked Questions (FAQs)

### 1.  Where does the name "malan" come from?

It's an extremely nerdy name based [on a character from the Stormlight Archive series](https://coppermind.net/wiki/Malan) by Brandon Sanderson.

