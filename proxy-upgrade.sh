#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

echo "[1/3] Pull images declared in compose..."
docker compose -f "$COMPOSE_FILE" pull mihomo metacubexd

echo "[2/3] Rebuild local cron image with latest base image..."
docker compose -f "$COMPOSE_FILE" build --pull provider-refresh-cron

echo "[3/3] Recreate services with updated images..."
docker compose -f "$COMPOSE_FILE" up -d

echo "Upgrade completed."
