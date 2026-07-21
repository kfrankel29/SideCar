# SideCar design QA

Authority: the client Figma **Final Draft** page. Viewport: iPhone 11 Pro,
375 × 812 logical pixels.

## Passed checks

- [x] Existing Figma file remained unchanged.
- [x] Opening, welcome, login, Sign Up, and verification sequence implemented.
- [x] Final Draft typography, monochrome palette, borders, radii, spacing, and
      fixed-width primary actions matched from same-state comparisons.
- [x] `417` partial verification state reproduced for direct comparison.
- [x] Login, Sign Up, Google authentication, forgot password, reset flow,
      profile completion, role choice, and permission recovery are interactive.
- [x] Native camera/library selection uses platform APIs rather than simulated
      controls.
- [x] Keyboard focus and error states do not break the 375 × 812 layouts.
- [x] Added recovery/gate screens reuse the established Final Draft patterns.
- [x] Later-milestone comments are documented but not implemented early.

## Evidence

- Reference crops: `docs/design/qa/final-draft-reference/`
- iOS captures: `docs/design/qa/ios-final/`
- Same-state comparisons: `docs/design/qa/comparisons/`
- Automated capture flow:
  `apps/mobile/integration_test/final_draft_visual_qa_test.dart`

## External completion items

Visual QA is passed locally. Live account/email/App Check testing requires the
client Firebase project to be on Blaze and configured as described in
`firebase/README.md`. TestFlight requires the final bundle identifier and an
Apple Developer/App Store Connect invitation.
