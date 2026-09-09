#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h:h}"
mobile_root="$repo_root/apps/mobile"
tool_root="/Users/shohruh/Documents/Personal/Bandmate/.codex-tools-bandmate-20260821"
flutter_bin="$tool_root/flutter-3.41.4-exact/flutter/bin/flutter"
android_sdk="$tool_root/android-sdk"
jdk_home="$tool_root/jdk-17.0.20+8/Contents/Home"
key_store="$mobile_root/android/keystore/sidecar-upload.jks"
keychain_service="com.kaileefrankel.sidecar.google-play-upload"
config_file="${1:-$mobile_root/.local/firebase-android.json}"

if [[ ! -f "$key_store" ]]; then
  print -u2 "Missing SideCar upload keystore: $key_store"
  exit 1
fi

if [[ ! -f "$config_file" ]]; then
  print -u2 "Missing Firebase configuration: $config_file"
  exit 1
fi

required_keys=(
  FIREBASE_API_KEY
  FIREBASE_APP_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_PROJECT_ID
  FIREBASE_STORAGE_BUCKET
  MAPS_API_KEY
)

for key in $required_keys; do
  if [[ -z $(jq -r --arg key "$key" '.[$key] // empty' "$config_file") ]]; then
    print -u2 "Firebase configuration is missing $key"
    exit 1
  fi
done

key_password="$(/usr/bin/security find-generic-password -a SideCar -s "$keychain_service" -w)"
maps_api_key="$(jq -r '.MAPS_API_KEY' "$config_file")"

cd "$mobile_root"
ANDROID_HOME="$android_sdk" \
ANDROID_SDK_ROOT="$android_sdk" \
JAVA_HOME="$jdk_home" \
SIDECAR_UPLOAD_KEYSTORE="$key_store" \
SIDECAR_UPLOAD_STORE_PASSWORD="$key_password" \
SIDECAR_UPLOAD_KEY_ALIAS="upload" \
SIDECAR_UPLOAD_KEY_PASSWORD="$key_password" \
MAPS_API_KEY="$maps_api_key" \
  "$flutter_bin" build appbundle --release --no-pub \
    --dart-define-from-file="$config_file"
