#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/docker-compose.yml}"

exec "$ROOT/scripts/compose.sh" -f "$COMPOSE_FILE" up -d
