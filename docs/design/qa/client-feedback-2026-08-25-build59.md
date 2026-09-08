# Build 59 client feedback release checklist

Source: nine client screenshots received on 2026-08-25. Each item below is a release gate for the next TestFlight build.

## F59-01 — Gas stations stay within one mile of the route

Source screenshots: 1, 6, 7, 8, 9.

Acceptance criteria:

- Every returned gas station is at most 1 mile (1,609.344 m) from the displayed route.
- A new address or city search refreshes the gas-station query and removes results from the previous query.
- The displayed station address matches the searched area; a San Mateo search cannot retain Arroyo Grande results.

Status: verified for build 60.

Evidence: the deployed callable now keys cached station results by both the
route and the current search anchors. Backend regression coverage and the live
iOS Simulator test verified independent San Jose and San Mateo searches, with
every returned station within one mile of the route and within the searched
area. The temporary QA ride was canceled during test cleanup.

## F59-02 — Map interaction and marker selection

Source screenshots: 1, 2, 3.

Acceptance criteria:

- Users can pan, zoom, and long-press the address-picker map.
- Tapping a gas-station marker selects that station and copies its formatted address into the search field.
- Tapping or long-pressing an address point makes the selected address visible before confirmation.

Status: verified for build 60.

Evidence: the native map enables scroll, zoom, rotate, tilt, tap, long-press,
and marker callbacks. Simulator UI tests verified marker selection updates the
search field and that a map-selected address can be confirmed.

## F59-03 — Native Google Maps on every route surface

Source screenshots: 2, 3.

Acceptance criteria:

- Address pickers, ride details, and confirmation route surfaces use an interactive Google map rather than a static image.
- Route, stop, and gas-station markers remain visible while the map is moved or zoomed.

Status: verified for build 60.

Evidence: both the stop picker and ride route preview render native
`GoogleMap` widgets on iOS and Android, using the decoded route polyline and
interactive endpoint/station markers. Driver and rider Simulator suites passed.

## F59-04 — Rider update notifications

Source screenshot: 1.

Acceptance criteria:

- Rider-targeted booking and ride updates create a notification for the rider.
- Foreground, background, notification-open/deep-link, unread state, and badge behavior are covered.
- Backend recipient selection is covered by tests; Simulator delivery/UI is verified separately from the physical TestFlight APNs gate.

Status: verified for build 60, with physical-device presentation as the final
TestFlight gate.

Evidence: notification recipient selection, payload content, foreground
presentation, deep links, unread state, and badge behavior have automated
coverage. Firebase production records show a post-registration iOS notification
accepted as delivered with zero failures. The archive uses the production APNs
entitlement; lock-screen presentation itself cannot be proven by iOS Simulator.

## F59-05 — Confirmation helper copy

Source screenshots: 4, 5.

Required text:

`Both addresses must be within 1 mile of the driver’s route or student housing (Isla Vista / UCSB housing).`

Status: verified for build 60 in the app and deployed booking validation.

## F59-06 — Address confirmation button order

Source screenshots: 6, 7.

Acceptance criteria:

- `Use this address` appears before the gas-station section when an address is selected.
- The action remains visible without scrolling through gas-station results.

Status: verified for build 60. Simulator UI coverage asserts the confirmation
action appears before the gas-station control and remains available without
traversing the station list.

## Regression gates

- Preserve the three-row visible search-result limit while keeping all result markers on the map.
- Preserve California address validation and Isla Vista/UCSB student-housing validation.
- Preserve paid-and-confirmed-only upcoming rides.
- Preserve fast pickup-code confirmation and existing M3–M5 flows.

## Build 60 verification summary

- Flutter analysis: clean.
- Flutter unit/widget suite: passed.
- Firebase Functions suite: passed.
- Driver iOS Simulator feedback suite: passed.
- Rider iOS Simulator feedback suite: passed.
- Live Firebase two-account map scenario: passed against deployed Functions.
- Firebase App Check: App Attest registered for the production iOS app; QA-only
  Simulator debug token registered for live integration testing.
- Google Maps backend: Geocoding API enabled and added to the restricted server
  key; live health request returned results successfully.
