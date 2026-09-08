**Comparison Target**

- Source visual truth: `/tmp/sidecar-driver-figma-375-2.png` (approved Final Draft Driver Home frame normalized from the local Figma export).
- Implementation screenshot: `/tmp/sidecar-driver-current-375-v2.png` (iOS Simulator render from the M3/M6 acceptance fixture).
- Combined evidence: `docs/design/qa/ios-final/m3-driver-home-final-comparison.png`.
- Viewport: 375 x 812 logical pixels, light theme, driver with one upcoming ride.
- Source pixels: 375 x 812. Implementation pixels: 375 x 812 after normalizing the 1080 x 2340 Simulator capture. Comparison density: 1:1.
- State note: the implementation fixture includes pending ride and navigation notifications, so the two red indicators are expected dynamic-state differences and were not removed.

**Findings**

- No actionable P0, P1, or P2 mismatches remain in the corrected Driver Home comparison.
- [P3] Dynamic notification indicators are visible only in the implementation.
  Location: upcoming-ride heading and bottom navigation.
  Evidence: the source frame is a clean static state; the Simulator fixture contains a pending request and a ride update.
  Impact: none to layout fidelity or core use.
  Fix: no product change; use a notification-free fixture only when a clean marketing capture is required.

**Required Fidelity Surfaces**

- Fonts and typography: the bundled SideCar serif family, weights, sizes, line heights, hierarchy, single-line truncation, price treatment, and booked-count optical weight match the approved frame closely.
- Spacing and layout rhythm: page margins, header position, CTA size, statistic cards, upcoming-ride heading, 118-pixel ride card, internal grid, divider, route labels, and compact booked badge are aligned at the same viewport.
- Colors and visual tokens: ivory background, blue primary surface, white cards, grey borders, muted labels, and navigation states use the project tokens and visually match the source.
- Image quality and asset fidelity: the profile avatar mask and exported navigation assets render sharply without placeholder art, inline SVG substitutes, or compression artifacts.
- Copy and content: all static labels match the approved screen; dynamic route, date, time, price, capacity, earnings, rating, and trip values preserve the same content structure.

**Full-view Comparison Evidence**

- `docs/design/qa/ios-final/m3-driver-home-final-comparison.png` places the normalized approved frame and corrected Simulator render in one 750 x 812 image.
- The full screen is readable at this size, including the important card typography and navigation icons, so a separate focused crop was not required.

**Comparison History**

1. Initial Build 63 evidence used a flexible row inside the upcoming-ride card. Time, price, route labels, and the booked badge drifted horizontally and vertically from the Figma grid.
2. The first correction replaced the flexible row with measured card geometry. The follow-up comparison still showed remaining time/price offsets, undersized route text, and an overly tall booked badge.
3. The final correction adjusted the measured positions, route typography, divider extent, and badge dimensions. The post-fix combined evidence shows no remaining P0/P1/P2 issue.

**Recovered Settings Screen Verification**

- The Profile/Settings page was intentionally restored from Git's local pre-redesign object history at the user's request. Only that screen's presentation was recovered.
- Current M6 actions remain connected: personal information, verification, password change, driver vehicle/insurance, rider payments, driver payouts, history, blocked users, invite, support, review, logout, and account deletion.
- Simulator evidence: `docs/design/qa/ios-final/m3-driver-profile-restored.png` at 1125 x 2436 pixels for a 375 x 812 logical viewport.
- This screen is documented as an intentional product exception to the new Final Draft Profile frame, not claimed as Figma parity.

**Open Questions**

- None blocking the Driver Home handoff. The Settings exception is explicit and user-directed.

**Implementation Checklist**

- [x] Correct Driver Home upcoming-ride card geometry.
- [x] Preserve live pending-request and navigation notification states.
- [x] Restore only the earlier Settings presentation while retaining M6 actions.
- [x] Verify Driver and Rider integration flows on the dedicated iPhone Simulator.
- [x] Keep focused geometry and recovered Settings widget coverage.

**Follow-up Polish**

- A notification-free fixture can be captured later if a clean App Store marketing image is needed.

final result: passed

## 2026-08-31 · Build 65 release verification

- Re-ran the complete mobile analysis and widget suite: `flutter analyze --no-pub`
  passed with no issues and all 168 tests passed.
- Re-ran Firebase Functions compilation and all 87 backend tests.
- Re-ran the full iOS visual/navigation matrix: 28 M1/M2 routes, 11 M3
  routes, 8 M4 scenarios, 2 M5 feedback scenarios, and the native review
  smoke scenario all passed.
- Re-ran the deployed M6 admin and rider/driver route feedback acceptance
  scenarios, including configuration restoration and transient-fixture cleanup.
- Reviewed all 55 fresh Simulator captures as contact sheets and compared the
  key Driver Home, My Rides, Post Ride, Ride Details, and restored Settings
  surfaces against the approved Final Draft references at the same viewport.
- Added `NSLocationWhenInUseUsageDescription`, resolving the location-purpose
  warning previously reported for Build 64.
- Archived and uploaded SideCar `0.1.0 (65)` with bundle ID
  `com.ridesidecar.app` and Apple team `3WHX6X6D64` (Amkai INC).
- App Store Connect reports Build 65 as `Complete`, binary state `Validated`,
  and `Testing`; it is automatically assigned to both `Internal QA` and `Test`.
- `Internal QA` contains two testers, including Kailee Frankel, and lists Build
  65 as an active internal build.

final result: passed

## 2026-08-31 · Client-account My Rides feedback

**Source and observed mismatch**

- Client-account evidence: `/Users/shohruh/Downloads/IMG_6666.PNG` showed Build 64 using the older tall, vertically stacked Driver My Rides cards and the blue exported add-square.
- Earlier-account evidence: `/Users/shohruh/Downloads/IMG_6673.PNG` showed the same old card structure, confirming the mismatch was shared presentation code rather than different account data.
- Driver design references: `docs/design/figma-final-draft/latest/23-my-rides-driver-a.png`, `docs/design/figma-final-draft/screens/28-23-my-rides-driver.png`, and the live Final Draft canvas.
- Rider design references: live Final Draft nodes `1105:1182` (Upcoming) and `1105:1100` (Past), inspected at the native 375 x 812 frame size after the Figma MCP Starter-plan quota was exhausted.

**Implemented correction**

- Replaced the Driver My Rides vertical route widgets with the Final Draft compact structure: date, time, price/per-seat, divider, horizontal origin/arrow/destination, booked badge, 34-pixel actions, and centered past status.
- Replaced the blue add-square raster with the Final Draft 40 x 40 soft-surface add control.
- Matched the 40-pixel segmented control and 34-pixel selected pill.
- Reworked Driver Requests into the Final Draft rider/profile, schedule, fare, horizontal route, and Decline/Accept structure.
- Reworked Rider My Rides from the old expanded seat/pickup card into the Final Draft driver/avatar/rating, schedule, fare, horizontal route, status, and compact action structure. Detailed pickup and seat information remains available in the ride and pickup-code flows rather than expanding the list widget.

**Post-fix evidence**

- Driver Upcoming: `docs/design/qa/ios-final/m3-driver-my-rides.png`.
- Driver Requests: `docs/design/qa/ios-final/m3-driver-requests.png`.
- Rider Upcoming: `docs/design/qa/ios-final/m3-rider-my-rides.png`.
- All captures are 1206 x 2622 Simulator pixels for the same 375 x 812 logical viewport used by the Final Draft frames.

**Verification**

- Focused Driver My Rides geometry widget test: passed.
- Milestone 4 payment, Rider My Rides tab, profile, and live-trip suite: 10/10 passed.
- iOS Flutter Driver acceptance: 2/2 scenarios passed, covering driver and rider home, post/find, My Rides, driver Requests and acceptance, owner/rider ride details, and profile.
- `flutter analyze --no-pub`: no issues found.
- `git diff --check`: clean.

**Remaining release boundary**

- These changes are verified locally and in the iOS Simulator. They are not represented by the already-published TestFlight Build 64 until a new archive is explicitly requested and uploaded.

final result: passed
