#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/docker-compose.yml}"
COMPOSE_BIN="$ROOT/scripts/compose.sh"

echo "[1/3] Pull images declared in compose..."
"$COMPOSE_BIN" -f "$COMPOSE_FILE" pull mihomo metacubexd

echo "[2/3] Rebuild local cron image with latest base image..."
"$COMPOSE_BIN" -f "$COMPOSE_FILE" build --pull provider-refresh-cron

echo "[3/3] Recreate services with updated images..."
"$COMPOSE_BIN" -f "$COMPOSE_FILE" up -d

echo "Upgrade completed."
