#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Remove stopped containers..."
docker container prune -f

echo "[2/3] Remove unused images..."
docker image prune -af

echo "[3/3] Remove unused build cache..."
docker builder prune -af

echo "Cleanup completed."
