#!/bin/zsh
set -euo pipefail

device="${1:?simulator device id is required}"
fixture_path="${SIDECAR_M6_FIXTURE_PATH:-/tmp/sidecar-m6-acceptance.json}"
flutter_bin="${SIDECAR_FLUTTER_BIN:-flutter}"

define_args=()
while IFS=$'\t' read -r key value; do
  case "$key" in
    M6_APPROVAL_OBJECT_PATH|M6_REJECTION_OBJECT_PATH) ;;
    *) define_args+=("--dart-define=${key}=${value}") ;;
  esac
done < <(/usr/bin/jq -r 'to_entries[] | [.key, .value] | @tsv' "$fixture_path")

"$flutter_bin" test \
  --no-pub \
  integration_test/live_m6_admin_acceptance_test.dart \
  -d "$device" \
  --reporter compact \
  "${define_args[@]}"
