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

if [[ ! -f "$key_store" ]]; then
  print -u2 "Missing SideCar upload keystore: $key_store"
  exit 1
fi

key_password="$(/usr/bin/security find-generic-password -a SideCar -s "$keychain_service" -w)"

cd "$mobile_root"
ANDROID_HOME="$android_sdk" \
ANDROID_SDK_ROOT="$android_sdk" \
JAVA_HOME="$jdk_home" \
SIDECAR_UPLOAD_KEYSTORE="$key_store" \
SIDECAR_UPLOAD_STORE_PASSWORD="$key_password" \
SIDECAR_UPLOAD_KEY_ALIAS="upload" \
SIDECAR_UPLOAD_KEY_PASSWORD="$key_password" \
  "$flutter_bin" build appbundle --release --no-pub
