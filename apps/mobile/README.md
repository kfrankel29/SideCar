# SideCar mobile

Flutter client for iOS and Android. The implemented scope covers the approved
Milestones 1 and 2: Final Draft account and profile flows, backend-controlled
configuration, identity and driver verification, vehicle details, role-aware
verification gating, insurance verification/fallback, and user safety actions.

## Structure

```text
lib/src/core/       bootstrap, configuration, errors, shared widgets
lib/src/features/   feature-owned domain, data, and presentation code
lib/src/routing/    application routes
lib/src/theme/      Final Draft visual tokens
integration_test/   same-state Final Draft screenshot flow
test/               domain, configuration, and viewport tests
```

Firebase and vendor SDKs are behind repository interfaces so the domain and UI
remain testable and later adapters can be replaced without restructuring the
application.

## Run locally

Create the ignored platform configuration described in
`../../firebase/README.md`, then run:

```sh
flutter pub get
flutter run -d <device> \
  --dart-define-from-file=.local/firebase-ios.json
```

Use `.local/firebase-android.json` for Android. A build without Firebase values
opens in visual-preview mode; protected account actions clearly report that the
backend is not configured.

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
```

The Final Draft integration capture uses the dedicated 375 × 812 simulator:

```sh
flutter drive \
  --driver=test_driver/final_draft_visual_qa_test.dart \
  --target=integration_test/final_draft_visual_qa_test.dart \
  -d <simulator-uuid>
```

Release/TestFlight builds must use the final bundle ID, real platform Firebase
App ID, registered App Check provider, Apple signing team, and incremented build
number. No credentials or generated platform configuration belong in Git.

Build the release archive through the guarded script so Firebase compile-time
configuration cannot be omitted:

```sh
./tool/build_ios_release.sh
```

## Xcode Cloud

The iOS workspace includes Xcode Cloud scripts that install Flutter and
CocoaPods, restore the ignored Firebase configuration, run static analysis and
tests, and prepare the release archive.

Add the following Firebase iOS values as secret workflow environment variables:
`FIREBASE_IOS_CLIENT_ID`, `FIREBASE_IOS_REVERSED_CLIENT_ID`,
`FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_GCM_SENDER_ID`,
`FIREBASE_IOS_PROJECT_ID`, `FIREBASE_IOS_STORAGE_BUCKET`, and
`FIREBASE_IOS_GOOGLE_APP_ID`. Configure the workflow to archive the `Runner`
scheme on changes to the release branch and distribute successful archives to
the internal TestFlight group. Set the first Xcode Cloud build number to `17`.
