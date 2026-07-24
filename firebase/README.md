# Firebase — Milestone 1 setup

The repository contains the deployable, non-secret Firebase foundation for
SideCar. The target project is `sidecar-fb0e7`; production credentials,
service-account files, signing keys, and local build configuration stay out of
Git.

## Console prerequisites

The client must complete these account-level steps before the live acceptance
test:

1. Upgrade the Firebase project from Spark to Blaze. Cloud Functions, the email
   extension, and production Storage/App Check usage depend on billing being
   available.
2. Create Firestore in Native mode and enable Cloud Storage.
3. Enable Firebase Authentication providers:
   - Email/Password;
   - Google.
4. Register the final Android package and iOS bundle identifier. Do not use the
   provisional `com.sidecar` identifiers for production records.
5. Add Android SHA-1 and SHA-256 fingerprints for Google sign-in and App Check.
6. Register App Check:
   - Android: Play Integrity;
   - iOS: App Attest with DeviceCheck fallback after the client Apple
     organization enrollment and Team ID are available.
7. Install the Firebase **Trigger Email** extension using the `mail` collection
   and configure an SMTP provider. The callable functions write one-time codes
   to this collection; the mobile app never sends email directly.

## Local platform configuration

Copy `apps/mobile/firebase_options.example.json` into two ignored local files,
one per registered Firebase app:

```text
apps/mobile/.local/firebase-ios.json
apps/mobile/.local/firebase-android.json
```

Each file uses its platform Firebase App ID. Add the iOS and web OAuth client
IDs for native Google sign-in. Copy
`ios/Flutter/GoogleAuth.xcconfig.example` to the ignored
`ios/Flutter/GoogleAuth.xcconfig` and set the reversed iOS client ID.

Example development commands:

```sh
flutter run -d <ios-device> \
  --dart-define-from-file=.local/firebase-ios.json

flutter run -d <android-device> \
  --dart-define-from-file=.local/firebase-android.json
```

Debug App Check tokens printed by each local build must be registered in the
Firebase console before protected callable functions can run.

## Backend configuration and deployment

From the repository root, after signing into the Firebase CLI:

```sh
firebase functions:secrets:set OTP_HASH_SECRET
cd firebase/functions
npm ci
npm run lint
cd ../..
firebase deploy --only remoteconfig,firestore:rules,firestore:indexes,storage,functions
```

Use a high-entropy random value for `OTP_HASH_SECRET`; never store it in a local
file or Git. The checked-in Remote Config template controls the M1 business
values, exact school-domain allow-list, and exact non-school test-email
exceptions. Change `config_version` during the
acceptance test to verify that a running app receives backend configuration
without a new build.

## Security model

- School-domain eligibility is enforced again in Cloud Functions; the client
  check is only immediate UI feedback.
- One-time codes are HMAC-protected, expire after ten minutes, have an attempt
  limit, and are consumed once.
- Profile documents and photos are owner-only in M1. Later milestones must add
  a deliberately limited public profile projection rather than widening these
  rules.
- App Check is enforced on callable functions. Release apps use platform
  attestation providers; debug builds use registered debug tokens.
