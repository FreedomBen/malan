#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Lint OpenAPI spec using the locally installed Spectral and ruleset (.spectral.yaml)
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SPECTRAL_BIN="$ROOT_DIR/assets/node_modules/.bin/spectral"

if [ ! -x "$SPECTRAL_BIN" ]; then
  echo "Error: Spectral not found at $SPECTRAL_BIN. Run 'cd assets && npm install' first." >&2
  exit 1
fi

exec "$SPECTRAL_BIN" lint "$ROOT_DIR/openapi.yaml" --fail-severity warn
