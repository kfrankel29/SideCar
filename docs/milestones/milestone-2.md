# Milestone 2 — Identity, Insurance, Vehicle, and Safety

Status: **active**

## Product scope

- Verify identity and driver licenses through the client-owned Stripe Identity
  verification flow.
- Verify driver insurance automatically through Axle.
- Offer manual insurance review only when Axle cannot confirm the policy.
- Collect the driver's vehicle year, make, model, color, license plate, and
  exterior photo.
- Prevent ride actions until the account has the verification required for its
  selected role.
- Support blocking and reporting users without exposing internal test tooling
  in release builds.
- Do not add the removed background-check flow.

## Implemented locally

- Replaceable verification and safety repository boundaries.
- Stripe Identity session creation and signed webhook handling in Firebase
  Functions.
- Verification status and vehicle storage models.
- Vehicle photo uploads with private storage rules and a server-owned manual
  insurance fallback that revalidates Axle failure state before accepting a
  document.
- Role-aware verification gating.
- Final Draft-aligned identity, driver-license, vehicle, verification-status,
  insurance-fallback, block, and report screens.
- Explicit loading, validation, timeout, provider-error, and permission states.
- Automated domain and 375 × 812 layout coverage.

## External inputs still required

- Axle sandbox access, API documentation, client identifier, and server-side
  credentials.

Secrets must be configured directly in Firebase or Secret Manager and must
never be placed in the Flutter client, repository, chat, or documentation.

## Acceptance criteria

- Stripe verification starts from the app and provider webhook events update
  the correct signed-in user's status.
- Axle completes automatic insurance verification.
- Manual insurance upload is unavailable until automatic verification fails or
  requires more information.
- A rider cannot access ride actions without verified identity.
- A driver cannot access ride actions without verified identity, insurance,
  and a complete vehicle.
- Block and report requests are authenticated, validated server-side, and
  persisted.
- iOS and Android builds pass automated checks and render the approved M2
  screens without overflow at the Final Draft viewport.

## Validation evidence

- 74 Flutter unit and widget tests pass, including typed-language profile
  persistence and completion without a stuck loading state.
- Four Firebase Functions tests pass for manual insurance file validation;
  Firebase Functions lint and build pass.
- Flutter analyzer passes.
- The complete M1 and M2 visual route suite passes on the 375 × 812 iOS
  simulator.
- The iOS app builds, installs, and launches successfully on the simulator.
- The Android debug APK builds successfully.
- The Stripe sandbox credential, verification-flow ID, webhook secret, and
  complete lifecycle subscriptions pass sanitized configuration checks.
- A signed synthetic Stripe event receives HTTP 200 from the deployed webhook;
  unsigned requests are rejected.
- A real Stripe sandbox Identity session was created, returned a hosted
  verification URL, and was canceled without affecting live users.
