#!/bin/sh

set -eu

export PATH="$HOME/flutter/bin:$PATH"
cd "${CI_PRIMARY_REPOSITORY_PATH:?CI_PRIMARY_REPOSITORY_PATH is required}/apps/mobile"

flutter analyze
flutter test --no-pub
