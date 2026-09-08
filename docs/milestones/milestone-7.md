# Milestone 7 — Polish and Store Submission

Authoritative source: client Google Drive document “Development Milestones &
Payment Schedule”, reviewed 2026-09-01.

Payment: $500.

## Current instruction boundary

- Prepare App Store Connect metadata and submission inputs.
- Do not select or assign a build.
- Do not add testers.
- Do not add screenshots yet.
- Leave App Review contact information blank until the client provides it.
- Do not add the version for review or submit it to Apple.

## App Store Connect metadata prepared

- App name: `SideCar: The Easy Way Home`
- Subtitle: `Student rides, shared costs`
- Primary category: Travel
- Secondary category: Social Networking
- Content rights: third-party content is used and the developer has the
  necessary rights.
- Age rating: owner override to 13+; App Store Connect displays the resulting
  regional 12+/13+ ratings.
- Price: Free in all price territories.
- Availability: United States only.
- Distribution: public and discoverable.
- Apple silicon Mac and Apple Vision Pro availability: disabled.
- Version metadata: promotional text, full description, keywords, support URL,
  marketing URL, copyright, review notes, and manual release.
- Privacy draft: 13 data types, all used for app functionality, linked to the
  user, and not used for tracking.
- Accessibility draft: iPhone declaration saved conservatively without claiming
  unverified accessibility support.
- In-app purchases and App Store subscriptions: none. Rider payments and driver
  payouts are for real-world ride cost sharing and are processed by Stripe.

## Verified live state — 2026-09-01

- App status remains `1.0 Prepare for Submission`.
- App Review contains no submitted items.
- Product page contains 0 screenshots and 0 previews.
- No build is selected on version 1.0.
- No App Store in-app purchase or subscription products exist.
- App Review contact fields remain blank.
- App Review sign-in credentials are not persisted because App Store Connect
  validates the required contact block when saving them.
- A persistent, verified App Review account has been prepared in Firebase. Its
  password is stored in macOS Keychain under service `SideCar App Review`; no
  credential is stored in this document or the repository.

## Remaining gates before submission

1. Replace the public waitlist-only privacy page with the app privacy policy in
   `docs/legal/app-privacy-policy-draft.md`, then verify the live URL.
2. Publish the App Privacy nutrition label only after the matching public policy
   is live.
3. Add the client-provided App Review contact name, phone number, and email.
4. Save the prepared App Review demo-account credentials after the contact block
   is complete.
5. Add final App Store screenshots for all required device families.
6. Select the approved release build only after final regression testing.
7. Recheck export compliance, privacy answers, screenshots, demo flow, and
   review notes against that exact build.
8. Add the version for review only after the owner explicitly approves
submission.
