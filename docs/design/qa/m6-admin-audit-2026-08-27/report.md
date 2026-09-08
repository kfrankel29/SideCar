# Milestone 6 admin acceptance report — 2026-08-27

## Outcome

Milestone 6 is implemented and deployed to Firebase Hosting and Functions. The
live acceptance path passed on the dedicated SideCar iOS Simulator, the normal
business configuration was restored, and all temporary QA data was removed.

The only remaining external issue is the public Namecheap DNS: the custom
domain still routes to Netlify. The working Firebase endpoint is
`https://sidecar-fb0e7.web.app/admin/`.

## Production fixes

- Removed the Milestone 6 marketing block from Overview.
- Replaced the opaque “Admin alerts” total with separate pending-insurance and
  open-dispute totals.
- Fixed Overview's production internal error by counting Auth users and pending
  verification documents safely across paginated users.
- Protected the signed-in administrator and every other admin-claimed account
  from suspend/ban actions.
- Limited moderation buttons to valid state transitions: active users can be
  suspended or banned, suspended users can be restored or banned, and banned
  users can only be restored.
- Replaced raw camelCase, snake_case, and dotted action/status values with
  readable labels.
- Shortened long IDs visually while keeping the complete value available.
- Fixed blank ride routes by reading the stored Google `displayName` fields.
- Ordered the audit log newest-first with snapshot-safe pagination.
- Replaced the failing signed-URL insurance flow with an authenticated,
  admin-only streaming endpoint. Documents use no-store caching and cannot be
  opened without a valid admin ID token.
- Preserved loading, empty, success, confirmation, validation, and error states.

## Live end-to-end coverage

An isolated production fixture created four temporary accounts: one admin, one
moderated app user, and two manual-insurance users. The iOS Simulator then:

1. Signed in as the temporary admin and verified the custom claim.
2. Loaded Overview totals and all user/verification records.
3. Confirmed an admin cannot suspend itself.
4. Opened a synthetic PDF through the authenticated document endpoint.
5. Approved one insurance submission and rejected another with a reason.
6. Read the live business configuration.
7. Published temporary fee, mileage, request-expiration, and auto-complete
   values.
8. Forced Remote Config refresh on the phone and verified all temporary values.
9. Restored the original configuration and independently verified the normal
   8%, $0.76/mile, 24-hour, 48-hour, and three-tier refund settings.
10. Suspended the test user and verified phone-app sign-in failed with the exact
    disabled-account support message.
11. Restored the user and verified sign-in succeeded.
12. Banned the user and verified phone-app sign-in failed again.
13. Restored the user again.
14. Loaded rides, bookings, payments, refunds, disputes, and newest-first audit
    records.
15. Verified audit entries for config publish, insurance approve/reject,
    suspend, ban, and restore.
16. Removed all four accounts, their Firestore documents, both Storage files,
    their temporary audit records, and the local secret fixture.

## Automated evidence

- Firebase Functions TypeScript compile: pass.
- Backend tests: 79/79 pass.
- Flutter analysis: no issues.
- Flutter unit/widget tests: 157/157 pass.
- `live_m6_admin_acceptance_test.dart` on SideCar Rider QA Simulator: pass.
- `live_m6_e2e_test.dart` on SideCar Rider QA Simulator: pass.
- `live_feedback_e2e_test.dart` on SideCar Rider QA Simulator: pass against
  deployed Firebase. It created an isolated Goleta-to-San Francisco ride,
  confirmed same-direction San Jose discovery and reverse-direction exclusion,
  checked San Jose and San Mateo gas results, enforced the 0.9-mile route safety
  margin, and resolved a returned map pin to a recognized California address.
- Firebase Hosting and all corrected functions: deployed successfully.
- Firebase admin endpoint: HTTP 200.

## Client follow-up — route pins and direct module tests

- Gas-station candidates are filtered at the deployed function and again when
  decoded by the phone app. The 0.9-mile calculation margin keeps pin centers
  visibly inside the one-mile product requirement.
- Added direct production-module tests for accounts, rides, and payments rather
  than relying on helper-only coverage. Account tests include moderation and
  verification states; ride tests include route/status/date/capacity/price
  mapping; payment tests include payment, refund, dispute, payout, and legacy
  record behavior.
- Deployed `getRideStopPickerContext`, `adminListUsers`, and `adminListRecords`.
- The App Check QA token was rotated for the dedicated Simulator. All temporary
  accounts, rides, bookings, local credentials, and token-output files were
  removed after the passing run.

## Dashboard visual evidence

- `01-overview-before.png` and `02-configuration-before.png`: source-state audit.
- `03-overview-after.png`: corrected Overview without milestone marketing copy.
- `04-01-users.png` through `04-09-audit-log.png`: every admin section.
- `05-mobile-audit.png`: phone-width responsive inspection.
- `06-live-*`: signed-in production data inspection from the existing Chrome
  admin session. These captures also document that an already-open custom-domain
  tab retained the older bundle while public DNS currently resolves to Netlify.

## External DNS issue

Current public DNS evidence:

- Apex A: `75.2.60.5`, `99.83.231.61` (Netlify)
- `www` CNAME: `shimmering-bubblegum-a31446.netlify.app`
- `https://ride-sidecar.com/admin/`: redirects to `www`
- `https://www.ride-sidecar.com/admin/`: HTTP 404
- `https://sidecar-fb0e7.web.app/admin/`: HTTP 200

Namecheap must remove the two Netlify web records and restore the Firebase A
and CNAME values. Do not change MX, SPF, DKIM, or DMARC records.
