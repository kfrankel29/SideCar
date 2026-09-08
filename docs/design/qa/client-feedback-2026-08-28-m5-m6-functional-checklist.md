# M5/M6 functional feedback checklist — 2026-08-28

Sources:

- Google Drive document `Test` (including all inline screenshots).
- Formal Development Milestones & Payment Schedule.

The client approved the complete Final Draft implementation on 2026-08-29.
This checklist covers the full screen hierarchy, exported Figma assets, exact
design tokens, functional feedback, and deployed-service acceptance.

Evidence labels:

- `[x]` verified by automated tests, production-backed simulator acceptance, or
  both.
- `[ ]` still requires a real external environment or physical-device gate.

## Final Draft implementation

- [x] Global ink, ivory, blue, secondary text, white, and border colors match
  the approved Final Draft tokens (`#111111`, `#FAF7F2`, `#2F4979`,
  `#8A8A8E`, `#FFFFFF`, and `#E2E2E2`).
- [x] Typography, spacing, cards, controls, sheets, dialogs, navigation, and
  state hierarchy follow the exported Final Draft references, except the
  Profile/Settings screen, whose earlier card-based layout was intentionally
  restored at the user's request while preserving all current M6 actions.
- [x] Figma-exported back, search, add, chevron, external-link, and six tab-bar
  icons are bundled and used by the matching controls instead of platform
  symbol substitutions.
- [x] Final Draft visual regression covers authentication, verification,
  rider/driver home and rides, search/post, payment/payout, messaging, ratings,
  safety, account, and support routes on iOS Simulator.
- [x] User-facing routes reject milestone, developer, preview, and other
  internal project copy.
- [x] Rate SideCar invokes the native StoreKit review request on iOS and opens
  the Play listing on Android instead of showing a release placeholder.

## M5 functional feedback

- [x] Public profiles expose a working Message action for any unblocked user.
- [x] A user pair has one conversation, even when they share multiple rides.
- [x] Ride context in messaging opens trip information on both rider and driver
  sides.
- [x] Rating Submit and Skip return home and dismiss the completed live trip.
- [x] Home sections are ordered Live Ride, Upcoming, then Leaving soon.
- [x] Only paid and confirmed bookings appear as upcoming rider trips.
- [x] Exact pickup/drop-off uses address search, an interactive native map,
  route display, pin selection, and route-limited gas stations.
- [x] Map supports pinch/scroll zoom, zoom controls, drag-to-pan, tap, and long
  press to select a location without keyboard overlap.
- [x] Gas stations load only on request and never exceed the one-mile route
  boundary.
- [x] Selecting a gas station or map pin selects its address.
- [x] The selected-address action appears before gas-station results.
- [x] Driver seat requests create My Rides attention and enqueue the expected
  push-notification event.
- [x] Rider lifecycle events create in-app attention and enqueue the expected
  push-notification events.
- [x] Successful rider payment immediately enqueues the driver notification.
- [x] Stripe payout onboarding is configured for an individual account rather
  than requesting company onboarding.
- [x] Admin business configuration exposes the Stripe card fee percentage and
  publishes it to the same Remote Config value used by checkout pricing.

## M6 functional feedback

- [x] Route and city search returns a same-direction ride whose driven route
  passes near the searched city, and excludes the reverse direction.
- [x] Gas-station list and map pins remain within one mile of the route and near
  the searched city.
- [x] Moving the map allows the user to reload gas stations for the visible
  area.
- [x] Live trips never duplicate under Upcoming.
- [x] Public profiles include a Reviews section with rating and written notes.
- [x] Rider and driver rating forms both accept notes, provide Skip, and return
  home after Submit or Skip.
- [x] A submitted seat request displays Pending until approved or denied.
- [x] Live-trip ETAs for both roles are calculated from the actual driver start
  time.
- [x] The backend schedules rider and driver 24-hour, 30-minute, and 10-minute
  departure reminder events with verified content and timing.
- [x] My Rides and Messages badges show unread counts and clear when the
  corresponding updates are opened.

## Milestone 6 admin acceptance

- [x] Admin authentication and first-password reauthentication/completion logic
  pass focused tests; the hosted production flow was previously exercised
  through its forced password-creation step.
- [x] Verification status and manual insurance review work end to end.
- [x] Suspend, ban, restore, and phone-side access enforcement work end to end.
- [x] Business configuration publishes and is activated by the mobile app
  without a new build.
- [x] Rides, bookings, payments, refunds, disputes, and audit history load and
  reflect admin actions.
- [x] Every admin mutation has authorization, validation, and audit coverage.

## Release gates

- [x] Flutter analysis passes.
- [x] Full Flutter unit/widget suite passes (168/168).
- [x] Full Firebase Functions suite passes (87/87).
- [x] Focused hosted-admin password suite passes (2/2).
- [x] Focused functional feedback and visual suites pass.
- [x] Rider and driver production-Firebase scenarios pass on iOS Simulator,
  including M4 regression plus live M5 and M6 acceptance.
- [x] The 2026-08-30 deployed route/map rerun passes same-direction discovery,
  reverse-direction rejection, San Jose/San Mateo gas filtering, the 0.9-mile
  boundary, and pin-address resolution without creating a duplicate QA ride.
- [x] The iOS native review channel compiles and passes a Simulator smoke test.
- [x] Current iOS Simulator and Android debug builds both compile with the
  native review integrations enabled.
- [x] Android 0.1.0 build 63 produces a release-signed AAB; `jarsigner`
  verifies it and Bundletool validates its bundle structure.
- [ ] Push token registration and push delivery evidence is captured for the
  client-owned Apple/Google notification configuration. Server event creation,
  APNs/FCM payload mapping, badge state, and token-registration code are
  verified; physical-device delivery cannot be proven by iOS Simulator.
- [x] The client-owned Apple identifier, signing team, notification capability,
  and Firebase iOS app linkage are complete for `com.ridesidecar.app` under
  team `3WHX6X6D64`. Firebase App Check uses App Attest with DeviceCheck
  fallback, and the isolated Simulator QA tokens are registered for live tests.
- [x] SideCar 0.1.0 build 63 archive and App Store IPA validate successfully.
- [x] SideCar 0.1.0 build 63 is processed in the client App Store Connect app
  (`Apple ID 6806675622`), assigned to the `Internal QA` group, and the internal
  tester state is `Invited` rather than `No Builds Available`.
- [ ] Google Play upload remains intentionally deferred while iOS TestFlight
  acceptance is in progress. The existing Play app record and validated
  release-signed AAB remain ready for a later internal-testing release.
