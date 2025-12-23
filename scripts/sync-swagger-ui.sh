#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname "$0")/.." && pwd)"
src="$repo_root/assets/node_modules/swagger-ui-dist"
dest="$repo_root/priv/static/swagger-ui"

if [ ! -d "$src" ]; then
  echo "swagger-ui-dist not found. Run 'cd assets && npm install' first." >&2
  exit 1
fi

mkdir -p "$dest"
cp "$src/swagger-ui.css" "$dest/"
cp "$src/swagger-ui.css.map" "$dest/" 2>/dev/null || true
cp "$src/swagger-ui-bundle.js" "$src/swagger-ui-standalone-preset.js" "$dest/"
cp "$src/favicon-16x16.png" "$src/favicon-32x32.png" "$dest/" 2>/dev/null || true

echo "Copied swagger-ui-dist assets to $dest"
