# Malan Authentication Service

Malan is a basic authentication service that you can drop into you microservice ecosystem, or even use as a base for a new Phoenix project

## Run Malan

If you have a clone of this repo, you can start Malan easily using Docker Compose:

```bash
docker-compose up
```

## Adding Malan service to an eco-system

If you are adding Malan to your current application, you can make use of [the example docker-compose file](https://github.com/FreedomBen/malan/blob/master/docker-compose-example.yml).  You will need to add Malan, and a Postgres for Malan to use as its data store.

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

## Setting up a local development environment

  You'll need to:

### 1.  Install Elixir and Mix

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

### 2.  Setup Hex

```bash
mix local.hex
```

If you need to install Phoenix separately, you can do so with hex:

```bash
mix archive.install hex phx_new 1.5.8
```

### 3.  Clone this repo and install dependencies

```bash
git clone https://github.com/freedomben/malan.git \
cd malan
mix deps.get
```

### 4.  Run migrations

Note:  You'll need Postgres to be running before completing this step.   If you are not using docker-compose, you can make use of the script at `script/start-postgres.sh` to quickly get a database running.

```bash
mix ecto.setup
```

### 5.  Star the Phoenix server

```bash
mix phx.server
```

## Helpful links regarding Phoenix

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix


