#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
CONF_FILE="${CONF_FILE:-$ROOT/scripts/provider-refresh.conf}"
PROVIDERS_DIR="${PROVIDERS_DIR:-$ROOT/mihomo/providers}"
MIHOMO_CONTAINER="${MIHOMO_CONTAINER:-mihomo}"
MIHOMO_CONFIG_FILE="${MIHOMO_CONFIG_FILE:-$ROOT/mihomo/config.yaml}"
MIHOMO_CONFIG_PATH="${MIHOMO_CONFIG_PATH:-/root/.config/mihomo/config.yaml}"
MIHOMO_CONTROLLER_URL="${MIHOMO_CONTROLLER_URL:-}"
MIHOMO_API_SECRET="${MIHOMO_API_SECRET:-}"
PROCESS_PROVIDER_NAME="${PROVIDER_NAME:-}"
PROCESS_PROVIDER_LIST="${PROVIDER_LIST:-}"
PROCESS_SUB_URL="${SUB_URL:-}"
PROCESS_SUB_UA="${SUB_UA:-}"
UA=""
TARGET_LIST=""
SUCCESS_PROVIDERS=()
FAILED_PROVIDERS=()
TEMP_FILES=()
SUCCESS_PROVIDER_COUNT=0
FAILED_PROVIDER_COUNT=0
TEMP_FILE_COUNT=0

# Keep runtime *_SUB_URL env overrides at highest priority.
# Use a newline-delimited string so the script still works on Bash 3.x
# even with `set -u` and no runtime overrides.
PROCESS_URL_OVERRIDES=""
while IFS= read -r env_line; do
  PROCESS_URL_OVERRIDES+="${env_line}"$'\n'
done < <(env | awk '/^[A-Za-z_][A-Za-z0-9_]*_SUB_URL=/{print}')

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ -f "$CONF_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$CONF_FILE"
  set +a
fi

# Re-apply runtime overrides after loading files.
if [[ -n "$PROCESS_URL_OVERRIDES" ]]; then
  while IFS= read -r env_line; do
    [[ -n "$env_line" ]] || continue
    key="${env_line%%=*}"
    value="${env_line#*=}"
    export "$key=$value"
  done <<< "$PROCESS_URL_OVERRIDES"
fi

if [[ -n "$PROCESS_SUB_URL" ]]; then
  SUB_URL="$PROCESS_SUB_URL"
fi

if [[ -n "$PROCESS_PROVIDER_LIST" ]]; then
  PROVIDER_LIST="$PROCESS_PROVIDER_LIST"
fi

if [[ -n "$PROCESS_SUB_UA" ]]; then
  SUB_UA="$PROCESS_SUB_UA"
fi

UA="${SUB_UA:-ClashforWindows/0.20.39}"

if [[ -n "$PROCESS_PROVIDER_NAME" ]]; then
  TARGET_LIST="$PROCESS_PROVIDER_NAME"
else
  TARGET_LIST="${PROVIDER_LIST:-qyt,equal}"
fi

TARGET_LIST="${TARGET_LIST//,/ }"

mkdir -p "$PROVIDERS_DIR"

cleanup() {
  local tmp
  if (( TEMP_FILE_COUNT == 0 )); then
    return
  fi

  for tmp in "${TEMP_FILES[@]}"; do
    rm -f "$tmp"
  done
}
trap cleanup EXIT

load_mihomo_api_secret() {
  if [[ -n "$MIHOMO_API_SECRET" ]]; then
    return 0
  fi

  if [[ -f "$MIHOMO_CONFIG_FILE" ]]; then
    MIHOMO_API_SECRET="$(
      sed -nE 's/^[[:space:]]*secret:[[:space:]]*"?([^"#]+)"?.*$/\1/p' "$MIHOMO_CONFIG_FILE" | head -n 1
    )"
  fi
}

reload_mihomo_via_api() {
  local controller_url
  local payload
  local -a urls headers

  urls=()
  if [[ -n "$MIHOMO_CONTROLLER_URL" ]]; then
    urls+=("$MIHOMO_CONTROLLER_URL")
  elif [[ -f "/.dockerenv" ]]; then
    urls+=("http://mihomo:9090" "http://127.0.0.1:9090" "http://localhost:9090")
  else
    urls+=("http://127.0.0.1:9090" "http://localhost:9090" "http://mihomo:9090")
  fi

  headers=(-H "Content-Type: application/json")
  if [[ -n "$MIHOMO_API_SECRET" ]]; then
    headers+=(-H "Authorization: Bearer $MIHOMO_API_SECRET")
  fi

  payload=$(printf '{"path":"%s"}' "$MIHOMO_CONFIG_PATH")

  for controller_url in "${urls[@]}"; do
    if curl -fsS --connect-timeout 3 --max-time 15 -X PUT \
      "${headers[@]}" \
      --data "$payload" \
      "${controller_url%/}/configs?force=true" >/dev/null; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] reloaded mihomo via API: ${controller_url%/}"
      return 0
    fi
  done

  return 1
}

restart_mihomo_via_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi

  if docker restart "$MIHOMO_CONTAINER" >/dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] restarted mihomo container: $MIHOMO_CONTAINER"
    return 0
  fi

  return 1
}

for provider in $TARGET_LIST; do
  provider="${provider// /}"
  if [[ -z "$provider" ]]; then
    continue
  fi

  if [[ ! "$provider" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Invalid provider name: '$provider'" >&2
    FAILED_PROVIDERS+=("$provider")
    ((FAILED_PROVIDER_COUNT += 1))
    continue
  fi

  upper_provider="$(printf '%s' "$provider" | tr '[:lower:]-' '[:upper:]_')"
  provider_url_var="${upper_provider}_SUB_URL"
  provider_url="${!provider_url_var:-}"

  # Backward compatibility for old qyt var naming.
  if [[ "$provider" == "qyt" && -z "$provider_url" ]]; then
    provider_url="${SUB_URL:-}"
  fi

  if [[ -z "$provider_url" || "$provider_url" == "TODO" ]]; then
    echo "Missing ${provider_url_var} for provider '$provider'. Set it in env/.env/$CONF_FILE." >&2
    FAILED_PROVIDERS+=("$provider")
    ((FAILED_PROVIDER_COUNT += 1))
    continue
  fi

  out_file="$PROVIDERS_DIR/${provider}.yaml"
  tmp_file="${out_file}.tmp"
  TEMP_FILES+=("$tmp_file")
  ((TEMP_FILE_COUNT += 1))

  if ! curl -fL --retry 3 --connect-timeout 10 --max-time 60 -A "$UA" "$provider_url" -o "$tmp_file"; then
    echo "Failed to refresh provider '$provider'." >&2
    FAILED_PROVIDERS+=("$provider")
    ((FAILED_PROVIDER_COUNT += 1))
    continue
  fi

  mv "$tmp_file" "$out_file"
  SUCCESS_PROVIDERS+=("$provider")
  ((SUCCESS_PROVIDER_COUNT += 1))
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] refreshed provider '$provider'"
done

if (( SUCCESS_PROVIDER_COUNT > 0 )); then
  load_mihomo_api_secret

  if ! reload_mihomo_via_api && ! restart_mihomo_via_docker; then
    echo "Refreshed providers, but failed to reload mihomo via API or docker restart." >&2
    exit 1
  fi
fi

if (( FAILED_PROVIDER_COUNT > 0 )); then
  echo "Failed providers: ${FAILED_PROVIDERS[*]}" >&2
  exit 1
fi

if (( SUCCESS_PROVIDER_COUNT == 0 )); then
  echo "No providers refreshed. Check PROVIDER_LIST / *_SUB_URL config." >&2
  exit 1
fi
