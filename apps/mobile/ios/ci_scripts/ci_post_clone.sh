#!/bin/sh

set -eu

repository_path="${CI_PRIMARY_REPOSITORY_PATH:?CI_PRIMARY_REPOSITORY_PATH is required}"
app_path="$repository_path/apps/mobile"
ios_path="$app_path/ios"
firebase_plist="$ios_path/Runner/GoogleService-Info.plist"
google_auth_config="$ios_path/Flutter/GoogleAuth.xcconfig"

if [ -z "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  echo "Missing GOOGLE_SERVICE_INFO_PLIST_BASE64 Xcode Cloud secret." >&2
  exit 1
fi

printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | /usr/bin/base64 -D > "$firebase_plist"
/usr/bin/plutil -lint "$firebase_plist"

bundle_id=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$firebase_plist")
if [ "$bundle_id" != "com.kaileefrankel.sidecar" ]; then
  echo "Firebase configuration bundle identifier does not match SideCar." >&2
  exit 1
fi

google_reversed_client_id=$(
  /usr/libexec/PlistBuddy -c "Print :REVERSED_CLIENT_ID" "$firebase_plist"
)
printf 'GOOGLE_REVERSED_CLIENT_ID=%s\n' "$google_reversed_client_id" \
  > "$google_auth_config"

if ! command -v flutter >/dev/null 2>&1; then
  git clone \
    --depth 1 \
    --branch stable \
    https://github.com/flutter/flutter.git \
    "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter precache --ios

cd "$app_path"
flutter pub get

if ! command -v pod >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi

firebase_api_key=$(/usr/libexec/PlistBuddy -c "Print :API_KEY" "$firebase_plist")
firebase_app_id=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$firebase_plist")
firebase_sender_id=$(
  /usr/libexec/PlistBuddy -c "Print :GCM_SENDER_ID" "$firebase_plist"
)
firebase_project_id=$(
  /usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$firebase_plist"
)
firebase_storage_bucket=$(
  /usr/libexec/PlistBuddy -c "Print :STORAGE_BUCKET" "$firebase_plist"
)

flutter build ios \
  --release \
  --config-only \
  --no-codesign \
  --dart-define="FIREBASE_API_KEY=$firebase_api_key" \
  --dart-define="FIREBASE_APP_ID=$firebase_app_id" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=$firebase_sender_id" \
  --dart-define="FIREBASE_PROJECT_ID=$firebase_project_id" \
  --dart-define="FIREBASE_STORAGE_BUCKET=$firebase_storage_bucket"
