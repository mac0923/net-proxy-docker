#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/docker-compose.yml}"
COMPOSE_BIN="$ROOT/scripts/compose.sh"

usage() {
  cat <<'EOF'
Usage: ./proxy.sh <command>

Commands:
  up           Start all services
  stop         Stop services without removing containers
  down         Stop and remove containers
  reload       Restart mihomo to reload config
  refresh      Refresh provider files and reload mihomo
  reset-cache  Back up and remove mihomo cache, then recreate mihomo
  upgrade      Pull images, rebuild cron image, and recreate services
  clean        Prune stopped containers, unused images, and build cache
  ps           Show Compose service status
  logs         Follow Compose logs
  help         Show this help
EOF
}

compose() {
  "$COMPOSE_BIN" -f "$COMPOSE_FILE" "$@"
}

command="${1:-help}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$command" in
  up)
    compose up -d "$@"
    ;;

  stop)
    compose stop "$@"
    ;;

  down)
    compose down "$@"
    ;;

  reload|restart)
    compose restart mihomo
    ;;

  refresh)
    exec bash "$ROOT/scripts/provider-refresh.sh" "$@"
    ;;

  reset-cache)
    cache_file="$ROOT/mihomo/cache.db"

    cd "$ROOT"

    if [[ -f "$cache_file" ]]; then
      timestamp="$(date +%Y%m%d-%H%M%S)"
      backup_file="$ROOT/mihomo/cache.db.bak-$timestamp"

      echo "[1/2] Backup and remove mihomo cache..."
      mv "$cache_file" "$backup_file"
      echo "Backed up cache to: $backup_file"
    else
      echo "[1/2] mihomo cache not found, skip backup."
    fi

    echo "[2/2] Recreate mihomo container..."
    compose up -d --force-recreate mihomo

    echo "Cache reset completed."
    ;;

  upgrade)
    echo "[1/3] Pull images declared in compose..."
    compose pull mihomo metacubexd

    echo "[2/3] Rebuild local cron image with pinned base image..."
    compose build --pull provider-refresh-cron

    echo "[3/3] Recreate services with updated images..."
    compose up -d

    echo "Upgrade completed."
    ;;

  clean)
    echo "[1/3] Remove stopped containers..."
    docker container prune -f

    echo "[2/3] Remove unused images..."
    docker image prune -af

    echo "[3/3] Remove unused build cache..."
    docker builder prune -af

    echo "Cleanup completed."
    ;;

  ps)
    compose ps "$@"
    ;;

  logs)
    compose logs -f "$@"
    ;;

  help|-h|--help)
    usage
    ;;

  *)
    echo "Unknown command: $command" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac
