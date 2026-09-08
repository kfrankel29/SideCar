# Milestone 7 — Google Play Preparation

Prepared: 2026-09-01

## Account and app

- Developer account: Kailee Frankel (organisation)
- Developer account ID: `6554040257682031205`
- Play Console app ID: `4974722933529027710`
- App: SideCar
- Package: `com.kaileefrankel.sidecar`
- Current status: Draft
- Installed audience: 0
- Initial setup progress at audit: 0 of 11 tasks
- Current setup progress after preparation: 7 of 11 tasks

## Current instruction boundary

- Prepare the Google Play listing and policy declarations.
- Do not upload or assign an Android App Bundle.
- Do not create an internal, closed, open, pre-registration, or production
  release.
- Do not submit changes for Google review.
- Leave public contact details and screenshots blank for now.

## Store listing copy

### App name

SideCar

### Short description

Find and share planned rides with verified students, secure payments and chat.

### Full description

SideCar helps verified college students share planned trips and split travel
costs.

Find a ride

Search by route and date, review driver profiles and ratings, choose an
available seat, and request pickup and drop-off points along the trip route.

Post a ride

Drivers can publish trips they are already taking, set seat availability and
luggage preferences, review rider requests, and manage upcoming rides.

Coordinate with confidence

- Student email and identity verification
- In-app messaging and trip notifications
- Rider and driver profiles, ratings, and reviews
- Women-only ride preferences
- Pickup codes and live trip details
- Block, report, and support tools

Secure payments

Pay for confirmed seats in the app. SideCar uses Stripe for payment processing
and driver payouts. Referral credits are automatically applied to eligible
rides.

SideCar is a cost-sharing platform for students coordinating trips they are
already taking. It is not a taxi or on-demand ride-hailing service.
Availability is currently focused on the UC Santa Barbara community and
supported California routes.

## Saved Play Console declarations

- Privacy policy URL: `https://www.ride-sidecar.com/privacy`. The URL is saved,
  but the current live page must still be replaced with the app-specific policy
  before review.
- Sign-in restricted: Yes.
- Review account: the persistent Firebase App Review account prepared for M7.
  Its credential and reviewer instructions were securely sent to Google Play;
  no password is stored in this document or repository.
- Ads: No ads.
- Advertising ID: Not used.
- Target audience: 18 and over.
- App type: App.
- Category: Travel and local.
- Tags: Taxi & lift-share; Travel & local; Maps & navigation.
- Government app: No.
- Health features: None.
- Financial features: Rewards, points, frequent flier miles, and other
  incentives, because SideCar provides referral ride credits. SideCar is not a
  bank, wallet, money-transfer service, lender, insurer, investment service, or
  cryptocurrency product.
- Default Store Listing: app name, 78-character short description, and full
  description saved as a draft.

## Data safety draft

Security and account handling:

- The app collects user data: Yes.
- Data is encrypted in transit: Yes.
- Users can request account deletion: Yes, in **Profile → Delete account**.
- A public deletion-request URL is required before the declaration can be
  completed; use the approved version of
  `docs/legal/account-deletion-page-draft.md`.
- No independent security review is claimed.
- No advertising or cross-app tracking is performed.

Collected data types:

- Personal info: name, email address, user IDs, address, phone number, and other
  profile information such as age, gender, language, student affiliation, and
  vehicle details.
- Financial info: user payment information, purchase history, and payout or
  refund information. Stripe processes card and bank details.
- Location: approximate and precise location used for place selection, route
  calculation, pickup, drop-off, and trip coordination.
- Messages: other in-app messages.
- Photos and videos: profile and verification images selected by the user.
- Files and documents: verification and insurance documents selected by the
  user.
- App activity: other user-generated content, including rides, ratings,
  reviews, support requests, safety reports, and referral activity.
- Device or other IDs: Firebase Authentication identifiers, App Check data,
  and notification tokens.

The primary purposes are app functionality, account management, security,
fraud prevention, compliance, and user communications. Optional activities such
as messaging, photo upload, driver verification, location permission, ride
payments, and payouts should be marked optional where the Play questionnaire
allows per-type collection choices.

Transfers to Firebase, Google Maps/Places/Routes, Stripe, and notification
infrastructure are service-provider processing required to operate the app.
The declaration must be checked against Google's current service-provider and
user-initiated-sharing exemptions before final submission.

## Content rating draft

- App category: all other app types / utility-social travel service.
- User-generated content: Yes.
- Users can communicate or exchange content: Yes, through ride-linked chat.
- Users can block and report other users: Yes.
- Location sharing: ride pickup, drop-off, and trip route details are shared
  with relevant ride participants.
- Purchases: real-world ride cost-sharing payments; no digital goods, loot
  boxes, simulated gambling, or Play Billing products.
- Violence, sexual content, drugs, profanity, gambling, and horror content:
  none supplied by the developer.
- The final IARC result should be accepted only after reviewing every answer and
  the generated regional ratings.

## Required assets not included yet

- 512 × 512 Play Store app icon derived from the approved SideCar icon.
- 1024 × 500 feature graphic.
- 2–8 phone screenshots, intentionally deferred by instruction.

## Remaining external gates

1. Publish an app-specific privacy policy at the saved privacy URL.
2. Publish a compliant account-and-data deletion request page.
3. Provide the public Store Listing email, optional phone number, and website.
4. Complete the Data safety declaration after the public deletion URL is live.
5. Provide the IARC contact email, complete the content-rating questionnaire,
   and review the generated regional ratings.
6. Add the approved 512 x 512 Play Store icon, 1024 x 500 feature graphic, and
   screenshots. Screenshots remain intentionally deferred.
7. Upload and verify the release-signed AAB only after explicit approval.
8. Do not start any testing or production rollout until separately approved.

## Verification evidence

- Play Dashboard showed **7 of 11 complete** after saving the declarations.
- Completed tasks shown by Play: privacy policy, sign-in details, ads, target
  audience, government apps, financial features, and health.
- The app remains **Draft** with installed audience 0.
- No Android App Bundle was uploaded, no testing or production release was
  created, and no changes were sent for review.
