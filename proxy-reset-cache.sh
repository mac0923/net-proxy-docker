#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/docker-compose.yml}"
COMPOSE_BIN="$ROOT/scripts/compose.sh"
CACHE_FILE="$ROOT/mihomo/cache.db"

cd "$ROOT"

if [[ -f "$CACHE_FILE" ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_file="$ROOT/mihomo/cache.db.bak-$timestamp"

  echo "[1/2] Backup and remove mihomo cache..."
  mv "$CACHE_FILE" "$backup_file"
  echo "Backed up cache to: $backup_file"
else
  echo "[1/2] mihomo cache not found, skip backup."
fi

echo "[2/2] Recreate mihomo container..."
"$COMPOSE_BIN" -f "$COMPOSE_FILE" up -d --force-recreate mihomo

echo "Cache reset completed."
