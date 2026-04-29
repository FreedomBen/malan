#!/usr/bin/env bash

if [ -z "${RELEASE_VERSION}" ]; then
  RELEASE_VERSION="$(git rev-parse HEAD)"
  echo "RELEASE_VERSION is not set.  Setting to HEAD (${RELEASE_VERSION})"
else
  echo "RELEASE_VERSION already set to '${RELEASE_VERSION}'"
fi

NETWORK_NAME="malan-ci-${RELEASE_VERSION}"
POSTGRES_CONTAINER="malan-ci-postgres-${RELEASE_VERSION}"
REDIS_CONTAINER="malan-ci-redis-${RELEASE_VERSION}"

cleanup() {
  echo "Cleaning up..."
  docker rm -f "${POSTGRES_CONTAINER}" 2>/dev/null
  docker rm -f "${REDIS_CONTAINER}" 2>/dev/null
  docker network rm "${NETWORK_NAME}" 2>/dev/null
}
trap cleanup EXIT

docker network create "${NETWORK_NAME}"

docker run -d \
  --name "${POSTGRES_CONTAINER}" \
  --network "${NETWORK_NAME}" \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:12.6-alpine

# Redis for the Hammer-backed rate limiter. Malan.RateLimiter uses
# Hammer.Redis, so the app refuses to boot without HAMMER_REDIS_URL.
docker run -d \
  --name "${REDIS_CONTAINER}" \
  --network "${NETWORK_NAME}" \
  redis:7.4-alpine

echo "Waiting for Postgres to be ready..."
for i in $(seq 1 30); do
  if docker exec "${POSTGRES_CONTAINER}" pg_isready -U postgres > /dev/null 2>&1; then
    echo "Postgres is ready"
    break
  fi
  if [ "${i}" -eq 30 ]; then
    echo "Timed out waiting for Postgres"
    exit 1
  fi
  sleep 1
done

echo "Waiting for Redis to be ready..."
for i in $(seq 1 30); do
  if docker exec "${REDIS_CONTAINER}" redis-cli PING 2>/dev/null | grep -q PONG; then
    echo "Redis is ready"
    break
  fi
  if [ "${i}" -eq 30 ]; then
    echo "Timed out waiting for Redis"
    exit 1
  fi
  sleep 1
done

docker run --rm \
  --network "${NETWORK_NAME}" \
  -e MIX_ENV=test \
  -e DB_HOSTNAME="${POSTGRES_CONTAINER}" \
  -e DB_USERNAME=postgres \
  -e DB_PASSWORD=postgres \
  -e HAMMER_REDIS_URL="redis://${REDIS_CONTAINER}:6379/0" \
  "docker.io/freedomben/malan-dev:${RELEASE_VERSION}" \
  mix test

