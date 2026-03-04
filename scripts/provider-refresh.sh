#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
CONF_FILE="${CONF_FILE:-$ROOT/scripts/provider-refresh.conf}"
PROVIDERS_DIR="${PROVIDERS_DIR:-$ROOT/mihomo/providers}"
MIHOMO_CONTAINER="${MIHOMO_CONTAINER:-mihomo}"
PROCESS_PROVIDER_NAME="${PROVIDER_NAME:-}"
PROCESS_PROVIDER_LIST="${PROVIDER_LIST:-}"
PROCESS_SUB_URL="${SUB_URL:-}"
PROCESS_SUB_UA="${SUB_UA:-}"
UA=""
TARGET_LIST=""
SUCCESS_PROVIDERS=()
FAILED_PROVIDERS=()
TEMP_FILES=()

# Keep runtime *_SUB_URL env overrides at highest priority.
declare -A PROCESS_URL_OVERRIDES=()
while IFS='=' read -r key _; do
  PROCESS_URL_OVERRIDES["$key"]="${!key}"
done < <(env | awk -F= '/^[A-Za-z_][A-Za-z0-9_]*_SUB_URL=/{print $1}')

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
for key in "${!PROCESS_URL_OVERRIDES[@]}"; do
  export "$key=${PROCESS_URL_OVERRIDES[$key]}"
done

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
  for tmp in "${TEMP_FILES[@]}"; do
    rm -f "$tmp"
  done
}
trap cleanup EXIT

for provider in $TARGET_LIST; do
  provider="${provider// /}"
  if [[ -z "$provider" ]]; then
    continue
  fi

  if [[ ! "$provider" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Invalid provider name: '$provider'" >&2
    FAILED_PROVIDERS+=("$provider")
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
    continue
  fi

  out_file="$PROVIDERS_DIR/${provider}.yaml"
  tmp_file="${out_file}.tmp"
  TEMP_FILES+=("$tmp_file")

  if ! curl -fL --retry 3 --connect-timeout 10 --max-time 60 -A "$UA" "$provider_url" -o "$tmp_file"; then
    echo "Failed to refresh provider '$provider'." >&2
    FAILED_PROVIDERS+=("$provider")
    continue
  fi

  mv "$tmp_file" "$out_file"
  SUCCESS_PROVIDERS+=("$provider")
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] refreshed provider '$provider'"
done

if (( ${#SUCCESS_PROVIDERS[@]} > 0 )); then
  docker restart "$MIHOMO_CONTAINER" >/dev/null
fi

if (( ${#FAILED_PROVIDERS[@]} > 0 )); then
  echo "Failed providers: ${FAILED_PROVIDERS[*]}" >&2
  exit 1
fi

if (( ${#SUCCESS_PROVIDERS[@]} == 0 )); then
  echo "No providers refreshed. Check PROVIDER_LIST / *_SUB_URL config." >&2
  exit 1
fi
