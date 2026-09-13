#!/bin/zsh
set -euo pipefail

device="${1:?simulator device id is required}"
admin_fixture="${SIDECAR_M6_FIXTURE_PATH:-/tmp/sidecar-m6-acceptance.json}"
flutter_bin="${SIDECAR_FLUTTER_BIN:-flutter}"
firebase_config="${SIDECAR_FIREBASE_CONFIG:?SIDECAR_FIREBASE_CONFIG is required}"

if [[ ! -f "$admin_fixture" || ! -f "$firebase_config" ]]; then
  print -u2 "Missing the M6 fixture or Firebase runtime configuration."
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
    M6_ADMIN_EMAIL|M6_ADMIN_PASSWORD|M6_USER_EMAIL|M6_USER_PASSWORD|M6_USER_UID)
      define_args+=("--dart-define=${key}=${value}")
      ;;
  esac
done < <(/usr/bin/jq -r 'to_entries[] | [.key, .value] | @tsv' "$admin_fixture")

MAPS_API_KEY="$maps_api_key" "$flutter_bin" test \
  --no-pub \
  integration_test/live_admin_forced_logout_test.dart \
  -d "$device" \
  --reporter compact \
  --dart-define-from-file="$firebase_config" \
  "${define_args[@]}"
