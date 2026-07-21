# Historical Milestone 1–2 design gap register

Status: **superseded by the client's Final Draft page on July 18, 2026**.
This file records the earlier copy-file review only. Current implementation
decisions are tracked in `final-draft-m1-audit.md`.

Target Figma copy: `SideCar Screen Shots (Copy)` (`x5rwxzLyTJuvhsG1ERl7Oq`)

The client source pages are unchanged. Generated work is isolated on:

- `00 — SideCar System` — reusable colors, type, icons, buttons, fields, chips, calendar, suggestions, and map components.
- `01 — Comment Resolutions` — ten Before/After sections with client comments and implementation notes outside phone frames.
- `02 — Missing Screens (M1–M2)` — fifteen genuine missing screens and states.

## Comment classification

| Type | Treatment |
| --- | --- |
| Visible UI correction | Source screen is duplicated and a visibly changed `After` is shown. |
| New screen or state | Added to the missing-screens page as a complete phone design. |
| Navigation or sequence note | Existing source and destination are documented together; no redundant phone is invented. |
| Developer behavior note | Kept outside the phone beside the affected screen or interaction state. |

## Page 01 — comment resolutions

1. Sign Up → six-digit school-email verification.
2. Identity/background verification → secure external-provider handoff.
3. Rider Home → existing Search Rides destination.
4. Search Rides → Google Places suggestions and calendar interaction state.
5. Search Results → `Closest match` selected as the default ranking.
6. Ride Details → static route plus route-aligned pickup/drop-off; pending request behavior documented outside the phone.
7. Trip in Progress → static route context with no live tracking.
8. Rating → compact optional-tip row.
9. Post a Ride → requested seat and luggage ranges.
10. Settings → visible destructive log-out row.

## Page 02 — genuine missing M1 screens/states

1. Forgot password — school email.
2. Password reset — six-digit code.
3. Create a new password.
4. Password reset complete.
5. Unsupported school domain — inline Sign Up validation state.
6. Choose profile photo source — camera or photo library.
7. Photo permission recovery — privacy explanation and `Open Settings`; no fake text field.
8. Profile-completion gate — shows the exact missing requirement and blocks ride actions.

## Page 02 — genuine missing M2 screens/states

9. Driver verification hub — ordered Persona, Yardstik, InsureGrid, license, and vehicle checklist.
10. External verification status — provider-complete and provider-pending states consolidated on one screen.
11. Insurance manual fallback — used only when InsureGrid cannot verify automatically.
12. Driver license upload — front and back.
13. Car profile — year, make/model, color, plate, and vehicle photo.
14. Block user confirmation.
15. Report user — structured reason selection and emergency guidance.

## Deliberately not duplicated as separate screens

- `This should go to screen 12` is a navigation connection.
- `No live tracking` is a map behavior/privacy rule.
- Requesting a seat creates a pending request and routes to the existing `My rides` request state.
- Payment remains disabled until the driver accepts.
- Vendor legal/consent pages belong to Persona, Yardstik, or InsureGrid; SideCar only needs handoff and status/fallback UI.

## Later-milestone gaps

Dispute status, booking empty/error states, notification-permission onboarding,
payment failure/retry, cancellation/refund detail, and admin review screens belong
to later milestones. They are recorded but are not being designed or implemented
until the user approves moving beyond the current M1 scope.
