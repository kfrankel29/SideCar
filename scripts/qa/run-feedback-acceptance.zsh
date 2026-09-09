#!/bin/zsh
set -euo pipefail

target="${1:?integration test target is required}"
device="${2:?simulator device id is required}"
fixture_path="${SIDECAR_FEEDBACK_FIXTURE_PATH:-/tmp/sidecar-feedback-acceptance.json}"
flutter_bin="${SIDECAR_FLUTTER_BIN:-flutter}"
firebase_config="${SIDECAR_FIREBASE_CONFIG:?SIDECAR_FIREBASE_CONFIG is required}"

if [[ ! -f "$firebase_config" ]]; then
  print -u2 "Missing Firebase configuration: $firebase_config"
  exit 1
fi

maps_api_key="$(jq -r '.MAPS_API_KEY // empty' "$firebase_config")"
if [[ -z "$maps_api_key" ]]; then
  print -u2 "Firebase configuration is missing MAPS_API_KEY"
  exit 1
fi

define_args=()
while IFS=$'\t' read -r key value; do
  case "$key" in
    M5_E2E_FIRST_EMAIL|M5_E2E_FIRST_PASSWORD|M5_E2E_SECOND_EMAIL|M5_E2E_SECOND_PASSWORD|SIDECAR_APP_CHECK_DEBUG_TOKEN|QA_ROUTE_ID|QA_BOOKING_ID)
      define_args+=("--dart-define=${key}=${value}")
      ;;
  esac
done < <(/usr/bin/jq -r 'to_entries[] | [.key, .value] | @tsv' "$fixture_path")

if [[ -n "${SIDECAR_VISUAL_PAUSE_MS:-}" ]]; then
  define_args+=("--dart-define=M5_VISUAL_PAUSE_MS=${SIDECAR_VISUAL_PAUSE_MS}")
fi

MAPS_API_KEY="$maps_api_key" "$flutter_bin" test \
  --no-pub \
  "$target" \
  -d "$device" \
  --reporter compact \
  --dart-define-from-file="$firebase_config" \
  "${define_args[@]}"
