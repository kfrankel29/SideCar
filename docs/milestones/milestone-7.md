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

## Verified live state — 2026-09-15

- App status remains `1.0 Prepare for Submission`.
- App Review contains no submitted items.
- Product page contains 0 screenshots and 0 previews.
- Build 73 is selected on version 1.0. Build 76 is processed, validated, uses
  exempt encryption only, and is active in internal TestFlight testing with no
  recorded crashes. The selected build must not be changed until the iOS login
  decision below is resolved and the resulting release build is verified.
- No App Store in-app purchase or subscription products exist.
- App Review contact name is `Kailee Frankel`; phone and email remain blank and
  were intentionally left untouched.
- App Review sign-in credentials are not persisted in App Store Connect because
  the required contact block is intentionally incomplete.
- Two persistent, verified App Review accounts are managed in Firebase: a rider
  and a driver. Their passwords are stored in macOS Keychain under service
  `SideCar App Review`; no credential is stored in this document or the
  repository.
- All 35 non-review Firebase Auth accounts and their linked test data were
  removed. The live project now contains exactly the rider and driver App
  Review accounts.
- `firebase/functions/scripts/m7_app_review_account.mjs reset` restores the
  paired rides, requests, history, chat, ratings, and notifications without a
  mobile build. `delete-data` removes those remote Firebase fixtures while
  keeping both reviewer logins active. `cleanup` removes both accounts and all
  of their Firebase data.
- `reset` preserves the passwords stored in macOS Keychain and recreates an
  account if a reviewer tests in-app account deletion. `smoke` verifies both
  Firebase logins and the deployed, App-Check-protected driver payout demo
  without printing credentials or tokens.
- Rider ACH checkout is disabled in the card-only app UI and enforced by the
  deployed callable backend. Driver bank payout setup remains enabled because
  it is a separate required flow.
- `apps/mobile/ios/Runner/PrivacyInfo.xcprivacy` is included in the Runner
  target. It declares the app's collected data, no tracking, and the approved
  `CA92.1` reason for the app-owned `UserDefaults` fresh-install marker.
- The Free Apps Agreement is active through July 15, 2027. The Paid Apps
  Agreement is unsigned and is not required for a free app whose Stripe charges
  pay for real-world transportation services.
- Price is USD 0.00; availability is United States only; public distribution is
  selected; Apple silicon Mac and Apple Vision Pro availability are off.
- Apple Standard EULA is selected. No custom EULA is required for the current
  submission; SideCar's separate Terms remain available in the app.

## Review notes draft

Use the rider credentials in the App Review username and password fields. Add
the driver password from macOS Keychain to the placeholder below immediately
before saving App Store Connect.

```text
SideCar is a planned-trip, cost-sharing app for eligible adult UCSB students.
It is not an on-demand taxi or commercial driver service. Service is limited to
California and the App Store version is available only in the United States.

RIDER
Email: app-review-sidecar@example.com
Password: supplied in the App Review password field

Use the Rider tab to find the preloaded UC Santa Barbara to Los Angeles
International Airport ride. My Rides includes a confirmed paid booking, a
pending request, a completed trip, pickup code access, chat, ratings, payment
history, reporting, blocking, and account deletion.

DRIVER
Email: app-review-driver-sidecar@example.com
Password: [insert from Keychain service "SideCar App Review"]

Use the Driver tab to view the same rides and requests, accept or decline the
pending request, start the confirmed trip, enter the rider's pickup code, and
complete the trip. The driver account has verified identity, insurance,
vehicle, and a review-only mock payout account. No real bank transfer occurs.

Stripe is in test mode. If testing a new card payment, use 4242 4242 4242 4242,
any future expiry, any three-digit CVC, and any valid US billing ZIP code.

Both accounts and their paired Firebase fixtures are persistent. Review-only
data can be restored or deleted remotely without a new app build.
```

## Confirmed App Store corrections still pending

- Replace the App Privacy URL `https://www.ride-sidecar.com/privacy`, which
  currently serves the old waitlist policy, with
  `https://sidecar-fb0e7.web.app/privacy/`.
- Add `https://sidecar-fb0e7.web.app/delete-account/` as the User Privacy
  Choices URL. Both Firebase-hosted pages return HTTP 200 and match the app.
- Add Search History to the privacy nutrition label because saved ride-search
  alerts persist pickup, destination, date, and preference criteria.
- Conservatively add Payment Info because Stripe's PaymentSheet collects card
  or bank details inside the app through an integrated third-party SDK. Keep it
  linked to the user, used for App Functionality, and not used for tracking.
- Change Age Assurance to Yes and change the age-rating override from 13+ to
  18+ so App Store metadata matches registration, the live privacy policy, and
  SideCar's Terms.
- Complete the account-level DSA declaration. Because distribution is outside
  the EU, Apple's guidance says the account is not acting as a trader on the
  App Store, but the Account Holder or Admin must make that legal declaration.

## Submission blocker requiring a new iOS build

Build 76 offers Google Sign-In but no equivalent privacy-preserving login
service. SideCar is categorized as Travel/Social Networking, so relying on the
education-app exception to App Review Guideline 4.8 is high risk even though
registration requires a UCSB account. Before selecting a release build, either:

1. add Sign in with Apple and a separate verified-UCSB-email linking flow; or
2. hide Google Sign-In on iOS and keep SideCar's own UCSB email/password flow.

Option 2 is the smaller, lower-risk release change. Google Sign-In can remain on
Android.

## Remaining gates before submission

1. Resolve the iOS login-service blocker and upload/verify the resulting build.
2. Apply and publish the confirmed privacy URL, nutrition-label, and age-rating
   corrections after owner confirmation.
3. Complete the DSA status declaration after owner confirmation.
4. Add the client-provided App Review phone number and email.
5. Save the rider credentials in the App Review username/password fields and
   list the driver credentials and role-specific walkthrough in Review Notes
   after the contact block is complete.
6. Add final App Store screenshots for all required device families.
7. Select the approved release build only after final regression testing.
8. Recheck export compliance, privacy answers, screenshots, demo flow, and
   review notes against that exact build.
9. Add the version for review only after the owner explicitly approves
   submission.
