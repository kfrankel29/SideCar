# Build 61 client feedback release checklist

Source: five client screenshots received on 2026-08-26. Every item below is a
release gate for the next TestFlight build and for completing Milestone 5.

## F60-01 — Route-corridor ride discovery

Source screenshot: 1.

Acceptance criteria:

- A ride is discoverable when the requested pickup and drop-off are near the
  driver's route and occur in the same travel direction.
- City searches use a practical city-area corridor rather than requiring the
  city center pin to be within the one-mile booking-stop limit.
- Example: a Santa Barbara to San Francisco ride can appear for a San Jose
  corridor search because its route passes through San Jose in that direction.
- Opposite-direction and unrelated routes remain excluded.

Status: implemented and verified. The deployed search now uses a city-sized
discovery corridor while preserving route direction. Focused tests cover the
one-mile rejection, San Jose corridor acceptance, and reverse-direction
rejection. The live two-account simulator test created a temporary
Goleta-to-San Francisco ride, found it from San Jose, rejected the reverse
search, and cancelled the temporary ride afterward.

## F60-02 — Strict one-mile gas-station markers

Source screenshots: 1, 2, 3.

Acceptance criteria:

- Every gas-station marker and list item is no farther than one mile from the
  decoded driver route.
- Search-result pins remain visually and semantically distinct from gas-station
  pins.
- Changing the city/address clears stale gas stations before new results load.
- The backend response and the map use the same filtered station collection.

Status: implemented and verified. Firebase filters candidates against the
decoded route and the requested city, and the app applies an independent
one-mile route-distance guard before rendering. Native simulator and live
San Jose/San Mateo scenarios confirmed all returned markers are within one
mile of the route and near the current search area.

## F60-03 — Month/day on ride cards and trip information

Source screenshots: 2, 4, 5.

Acceptance criteria:

- Every reusable ride card shows the departure month/day together with time.
- Rider search results show the month/day.
- Rider and driver trip-information surfaces show the same departure date and
  time without relying only on the search-results header.

Status: implemented and verified. Reusable ride cards and owner trip details
now show month/day with the departure time. Rider trip details retain their
existing full short-date presentation. Focused widget tests cover the card
date and the native M3/M4 simulator passes cover the trip surfaces.

## Regression gates

- Preserve California-only posting and booking restrictions.
- Preserve the one-mile exact pickup/drop-off booking rule and Isla Vista/UCSB
  student-housing exception.
- Preserve route direction ordering for pickup before drop-off.
- Preserve the three-row visible place-result limit while keeping all relevant
  markers on the map.
- Preserve paid-and-confirmed-only upcoming rides, notifications, messaging,
  safety, and existing M3-M5 flows.

## Required release evidence

- Focused backend tests for city-corridor direction and strict station distance.
- Focused Flutter widget/integration tests for date presentation and map-marker
  filtering.
- Full Flutter analysis and test suite.
- Full Firebase Functions test suite.
- Rider and driver iOS Simulator scenarios.
- Live Firebase two-account route-search scenario, with temporary QA data
  cleaned up afterward.
- New signed archive and successful App Store Connect upload.

## Verification evidence

- Flutter analysis: no issues.
- Flutter unit/widget suite: 156/156 passed.
- Firebase Functions suite: 66/66 passed.
- Focused routing suite: 7/7 passed.
- Focused ride model and card UI suite: 21/21 passed.
- Native iOS M3 simulator scenarios: 2/2 passed.
- Native iOS M4 simulator scenarios: 6/6 passed.
- Native iOS current-feedback scenarios: 2/2 passed.
- Live Firebase two-account feedback scenario: 1/1 passed; QA ride cleaned up.
- Firebase `searchRides` deployment: successful on 2026-08-26.
- Signed archive: `SideCar 0.1.0 (61).xcarchive`, copied into Xcode
  Organizer's 2026-08-26 archive folder.
- App Store Connect upload: succeeded on 2026-08-26 at 12:39 PM; Apple package
  processing completed. Build 61 is currently blocked from testers only by the
  App Store Connect export-compliance declaration.
