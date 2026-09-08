# Client feedback — M6 follow-up — 2026-08-27

## Feedback 1: gas stations outside one mile

Client report: gas-station pins outside one mile of the driver's route were
still visible.

Resolution:

- Enforce a 0.9-mile server-side route-distance margin.
- Apply the same 0.9-mile safety filter when the mobile app decodes results.
- Keep search-city proximity separate from route proximity so both conditions
  must pass.
- Verify live with San Jose and San Mateo searches on a Goleta-to-San Francisco
  route. Every returned station was inside 0.9 miles and near its search anchor.

## Feedback 2: direct tests for high-risk admin modules

Client report: payments, rides, and accounts did not have direct module tests.

Resolution:

- Added direct account record tests for access, moderation, verification,
  profile, vehicle, insurance, and timestamp states.
- Added direct ride record tests for nested and legacy route names, status,
  schedule, capacity, and price fields.
- Added direct booking/payment tests for paid and excluded records, refunds,
  disputes, payouts, lifecycle dates, and legacy fare fields.

## Verification

- Backend tests: 87/87 passed.
- Flutter unit/widget tests: 166/166 passed.
- Flutter analysis: no issues.
- Live iOS Simulator deployed-Firebase scenario: passed.
- The 2026-08-30 rerun reused the dedicated QA route so it could not collide
  with its own hydrated fixture. Same-direction discovery, reverse-direction
  rejection, San Jose/San Mateo gas filtering, the 0.9-mile safety boundary,
  and map-pin address resolution all passed again.
- Transient QA records were removed after the run; the restricted reusable QA
  fixture remains available for regression testing.
