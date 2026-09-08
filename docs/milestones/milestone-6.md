# Milestone 6 — Admin Tools

Authoritative source: client Google Drive document “Development Milestones &
Payment Schedule”, reviewed 2026-08-27.

Payment: $500.

## Release gates

- [x] Admin authentication is restricted to explicitly authorized admin users.
- [x] Dashboard shows each user's profile and verification status across ID,
  driver's license, and insurance/manual-insurance review.
- [x] Admin can approve or reject a pending manual insurance document with a
  reason and audit trail.
- [x] Admin can suspend, ban, and restore a user. Restricted users are blocked
  from protected app actions by trusted backend checks.
- [x] Admin can edit platform fee amount and type.
- [x] Admin can edit the Stripe card fee percentage used by checkout pricing.
- [x] Admin can edit the IRS mileage rate.
- [x] Admin can edit refund percentages and cancellation windows.
- [x] Admin can edit accepted-request expiration and trip auto-complete windows.
- [x] Config edits publish to Firebase Remote Config and become visible to the
  app without a new mobile build.
- [x] Dashboard can view rides, bookings, payments, refunds, and disputed trips.
- [x] Every admin mutation records who changed what and when.
- [x] Backend authorization, validation, and mutation behavior have automated
  tests.
- [x] Dashboard has loading, empty, success, and error states and builds cleanly.
- [x] Live acceptance test covers every admin action and confirms a config
  change reaches the mobile app without rebuilding.
- [x] iOS Simulator regression confirms existing rider/driver flows remain
  functional after the M6 backend deployment.

## Acceptance test

The client can perform every listed admin action from the dashboard, and a
backend config change made there appears in the mobile app without a new build.

## Verification evidence — 2026-08-29

- Firebase Functions, Hosting, and Remote Config deployed successfully.
- The verified production dashboard endpoint is
  `https://sidecar-fb0e7.web.app/admin/`.
- Unauthenticated production callable request returns HTTP 401 / `UNAUTHENTICATED`.
- Functions compile cleanly and all 87 backend tests pass, including direct
  account, ride, payment, refund, and dispute module coverage.
- Flutter analysis reports no issues and all 166 mobile unit/widget tests pass.
- The focused first-password suite passes both the immediate-reauthentication
  path and the password-updated/post-completion failure recovery path.
- Dashboard acceptance covered all ten sections, production record data, empty
  states, invalid configuration input, and desktop/phone layouts.
- The isolated production acceptance test uses dedicated reusable QA accounts
  and insurance documents, then verifies secure document access, approve/reject,
  config publish/restore, suspend/ban/restore, disabled phone-app sign-in,
  operational records, and audit entries. Transient records are reset between
  runs while the approved reusable QA accounts remain available for regression
  testing.
- Two iOS Simulator live M6 tests pass: one exercises every deployed admin
  operation and phone-side effect, and one independently verifies the restored
  fee, mileage, refund, request-expiry, and auto-complete values from Firebase
  Remote Config.
- iOS Simulator focused feedback regression passes rating submit/skip and map
  behavior (limited list rows, retained pins, and map controls).
- A deployed-Firebase iOS Simulator scenario passes route creation, San Jose
  corridor discovery, opposite-direction rejection, San Jose/San Mateo gas
  searches, the 0.9-mile route safety margin, and map-pin address resolution.
- The legacy production M4 regression also passes women-only ride creation,
  immediate driver refresh, user blocking/unblocking, and cleanup of transient
  test records.
- The complete Final Draft visual regression passes on iOS Simulator across
  authentication, verification, rider/driver, rides, payments, messaging,
  safety, rating, account, and support routes. It uses the exact approved
  palette and bundled Figma navigation/control assets, with no milestone or
  internal copy on user routes.

## Final verification evidence — 2026-08-29

- Flutter analysis: no issues.
- Flutter unit/widget suite: 166/166 passed.
- Firebase Functions build and test suite: 87/87 passed.
- Hosted first-password focused suite: 2/2 passed.
- Rider and driver Final Draft/feedback simulator suites pass, including all
  seven M4 visual scenarios on the driver simulator and both M5 feedback
  scenarios on each simulator.
- Live M5 deployed-Firebase acceptance passes messaging, delivery/read state,
  block/report enforcement, driver-to-rider rating, and rider trip rating.
- Live route/map acceptance passes same-direction city discovery,
  reverse-direction exclusion, route/city gas filtering, and map address
  resolution.
- Live M6 acceptance passes all deployed admin operations and phone-side
  effects, restores the original business configuration, and a separate rider
  simulator readback confirms the restored Remote Config values.

## Current regression evidence — 2026-08-30

- Flutter analysis passes with no issues and the full 166-test mobile
  unit/widget suite passes.
- Firebase Functions compile cleanly and all 87 direct backend tests pass.
- Both hosted first-password tests pass.
- The deployed route/map feedback scenario passes again on iOS Simulator using
  the dedicated reusable QA route: same-direction San Jose discovery,
  opposite-direction exclusion, San Jose/San Mateo gas-station filtering,
  the 0.9-mile route margin, and selected-pin address resolution.
- The route feedback runner now reuses its hydrated fixture instead of posting
  an overlapping ride, and transient QA records are reset after acceptance.
- Rate SideCar now invokes StoreKit on iOS and the Play listing on Android; the
  iOS native channel compiles and passes a 375 x 812 Simulator smoke test.
- Current iOS Simulator and Android debug builds compile successfully after
  the native review integration.
- Android 0.1.0 build 63 now produces a release-signed AAB. `jarsigner`
  verifies the archive and Bundletool validates the app-bundle structure.
- The new Firebase iOS app (`com.ridesidecar.app`) has App Attest configured
  with DeviceCheck fallback. Both isolated Simulator QA debug tokens are
  registered without weakening production enforcement.
- The live M6 admin acceptance passes again after resetting only the reusable
  QA records. It verifies secure insurance document access, approve/reject,
  self-lockout prevention, suspend/ban/restore, disabled phone-app sign-in,
  configuration publish and mobile readback, operational records, audit
  entries, and restoration of the original state.
- The live route/map acceptance passes again on a separate Simulator after the
  Firebase migration: same-direction discovery, reverse-direction rejection,
  route/city gas filtering, the 0.9-mile boundary, and selected-pin address
  resolution.
- The live M5 two-account acceptance passes again after the Firebase migration,
  covering the hydrated route, stop picker, messaging delivery/read state,
  block/report enforcement, and rider/driver rating behavior.
- App Store Connect build `0.1.0 (63)` is processed and assigned to the
  `Internal QA` group. Saving the build test information cleared the stale
  `No Builds Available` state; the internal tester now shows `Invited`.

## Public-domain verification — 2026-08-29

- `https://www.ride-sidecar.com/` returns the SideCar landing page over HTTPS.
- `https://admin.ride-sidecar.com/` returns the SideCar admin login over HTTPS
  and resolves its app at `/admin/`.
- The landing page and admin dashboard therefore coexist on the SideCar domain
  without replacing one another.
- The direct Firebase fallback remains
  `https://sidecar-fb0e7.web.app/admin/`.

## Remaining external release gates

- Accept build 65 in the TestFlight app and capture physical-device APNs
  presentation. Server event creation, payload mapping, notification capability,
  Firebase linkage, and Simulator behavior are verified, but Simulator evidence
  is not physical push-delivery evidence.
- The client Google Play organization already contains the draft SideCar app
  record for `com.kaileefrankel.sidecar`, and the validated build 63 AAB is
  ready for its internal-testing release flow. Google Play upload/rollout is
  intentionally deferred until the current iOS TestFlight acceptance is done.

## Build 65 release status — 2026-08-31

- SideCar `0.1.0 (65)` uploaded successfully under Amkai INC.
- App Store Connect upload status: `Complete`; binary state: `Validated`.
- TestFlight status: `Testing`, expiring in 90 days.
- Internal groups: `Internal QA` and `Test`.
- `Internal QA`: two testers and three builds; Build 65 is present and active.
- The Build 64 location-purpose warning is addressed by the Build 65
  `NSLocationWhenInUseUsageDescription` entry.
