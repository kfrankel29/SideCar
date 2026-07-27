#!/bin/sh

set -eu

repository_path="${CI_PRIMARY_REPOSITORY_PATH:?CI_PRIMARY_REPOSITORY_PATH is required}"
app_path="$repository_path/apps/mobile"
ios_path="$app_path/ios"
firebase_plist="$ios_path/Runner/GoogleService-Info.plist"
google_auth_config="$ios_path/Flutter/GoogleAuth.xcconfig"

required_firebase_variables="
FIREBASE_IOS_CLIENT_ID
FIREBASE_IOS_REVERSED_CLIENT_ID
FIREBASE_IOS_API_KEY
FIREBASE_IOS_GCM_SENDER_ID
FIREBASE_IOS_PROJECT_ID
FIREBASE_IOS_STORAGE_BUCKET
FIREBASE_IOS_GOOGLE_APP_ID
"

for variable_name in $required_firebase_variables; do
  eval "variable_value=\${$variable_name:-}"
  if [ -z "$variable_value" ]; then
    echo "Missing $variable_name Xcode Cloud variable." >&2
    exit 1
  fi
done

/usr/bin/plutil -create xml1 "$firebase_plist"
/usr/bin/plutil -insert CLIENT_ID -string "$FIREBASE_IOS_CLIENT_ID" "$firebase_plist"
/usr/bin/plutil -insert REVERSED_CLIENT_ID -string "$FIREBASE_IOS_REVERSED_CLIENT_ID" "$firebase_plist"
/usr/bin/plutil -insert API_KEY -string "$FIREBASE_IOS_API_KEY" "$firebase_plist"
/usr/bin/plutil -insert GCM_SENDER_ID -string "$FIREBASE_IOS_GCM_SENDER_ID" "$firebase_plist"
/usr/bin/plutil -insert PLIST_VERSION -string "1" "$firebase_plist"
/usr/bin/plutil -insert BUNDLE_ID -string "com.kaileefrankel.sidecar" "$firebase_plist"
/usr/bin/plutil -insert PROJECT_ID -string "$FIREBASE_IOS_PROJECT_ID" "$firebase_plist"
/usr/bin/plutil -insert STORAGE_BUCKET -string "$FIREBASE_IOS_STORAGE_BUCKET" "$firebase_plist"
/usr/bin/plutil -insert IS_ADS_ENABLED -bool false "$firebase_plist"
/usr/bin/plutil -insert IS_ANALYTICS_ENABLED -bool false "$firebase_plist"
/usr/bin/plutil -insert IS_APPINVITE_ENABLED -bool true "$firebase_plist"
/usr/bin/plutil -insert IS_GCM_ENABLED -bool true "$firebase_plist"
/usr/bin/plutil -insert IS_SIGNIN_ENABLED -bool true "$firebase_plist"
/usr/bin/plutil -insert GOOGLE_APP_ID -string "$FIREBASE_IOS_GOOGLE_APP_ID" "$firebase_plist"
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

build_number=$(
  sed -n 's/^version:.*+\([0-9][0-9]*\)$/\1/p' pubspec.yaml
)

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  case "$CI_BUILD_NUMBER" in
    *[!0-9]*)
      echo "CI_BUILD_NUMBER must be numeric." >&2
      exit 1
      ;;
  esac
  build_number=$((15 + CI_BUILD_NUMBER))
fi

if [ -z "$build_number" ]; then
  echo "Unable to determine the iOS build number." >&2
  exit 1
fi

echo "Configuring TestFlight build number $build_number."

flutter build ios \
  --release \
  --config-only \
  --no-codesign \
  --build-number="$build_number" \
  --dart-define="FIREBASE_API_KEY=$firebase_api_key" \
  --dart-define="FIREBASE_APP_ID=$firebase_app_id" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=$firebase_sender_id" \
  --dart-define="FIREBASE_PROJECT_ID=$firebase_project_id" \
  --dart-define="FIREBASE_STORAGE_BUCKET=$firebase_storage_bucket"
