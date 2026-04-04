#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Manual one-shot refresh:
# 1) download latest provider files by list
# 2) reload mihomo to apply provider changes
exec bash "$ROOT/scripts/provider-refresh.sh"
