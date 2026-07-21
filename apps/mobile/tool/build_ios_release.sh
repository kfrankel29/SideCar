#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
app_dir=${script_dir:h}
config_file=${1:-$app_dir/.local/firebase-ios.json}

if [[ ! -f $config_file ]]; then
  print -u2 "Missing Firebase configuration: $config_file"
  exit 1
fi

required_keys=(
  FIREBASE_API_KEY
  FIREBASE_APP_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_PROJECT_ID
  FIREBASE_STORAGE_BUCKET
)

for key in $required_keys; do
  if [[ -z $(jq -r --arg key "$key" '.[$key] // empty' "$config_file") ]]; then
    print -u2 "Firebase configuration is missing $key"
    exit 1
  fi
done

cd "$app_dir"
flutter build ipa --release --dart-define-from-file="$config_file"

archive_plist=$app_dir/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Info.plist
expected_build=$(sed -nE 's/^version: [^+]+\+([0-9]+)$/\1/p' pubspec.yaml)
actual_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$archive_plist")

if [[ $actual_build != $expected_build ]]; then
  print -u2 "Archive build mismatch: expected $expected_build, found $actual_build"
  exit 1
fi

print "Validated Firebase-configured iOS archive build $actual_build"
