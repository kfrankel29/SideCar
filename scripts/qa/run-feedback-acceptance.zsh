#!/bin/zsh
set -euo pipefail

target="${1:?integration test target is required}"
device="${2:?simulator device id is required}"
fixture_path="${SIDECAR_FEEDBACK_FIXTURE_PATH:-/tmp/sidecar-feedback-acceptance.json}"
flutter_bin="${SIDECAR_FLUTTER_BIN:-flutter}"

define_args=()
while IFS=$'\t' read -r key value; do
  case "$key" in
    M5_E2E_FIRST_EMAIL|M5_E2E_FIRST_PASSWORD|M5_E2E_SECOND_EMAIL|M5_E2E_SECOND_PASSWORD|SIDECAR_APP_CHECK_DEBUG_TOKEN|QA_ROUTE_ID|QA_BOOKING_ID)
      define_args+=("--dart-define=${key}=${value}")
      ;;
  esac
done < <(/usr/bin/jq -r 'to_entries[] | [.key, .value] | @tsv' "$fixture_path")

"$flutter_bin" test \
  --no-pub \
  "$target" \
  -d "$device" \
  --reporter compact \
  "${define_args[@]}"
