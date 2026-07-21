# Final Draft — Milestone 1 implementation audit

Design authority: client Figma `SideCar Screen Shots`, page **Final Draft**.
The former Draft 1 and Draft 2 pages are obsolete. The client file is read-only
for implementation work.

## Implemented M1 sequence

1. Opening/loading.
2. Login/sign-up choice.
3. Login, including native Google authentication and forgot-password entry.
4. Sign Up with exact-domain eligibility feedback.
5. Six-digit school-email verification, resend timer, and one-time-code entry.
6. Required profile setup with camera/photo-library source selection.
7. Photo-permission recovery through system Settings.
8. Welcome-aboard role choice.
9. Profile-completion gate before ride actions.
10. Password reset: school email, six-digit code, new password, and completion.

## Comment interpretation

Final Draft comments were treated as interaction specifications where they
describe navigation, native authentication, external handoffs, or later screen
sequence. Comments are not rendered inside the app. Visible M1 states were
implemented; ride search/posting, payments, verification vendors, maps,
messaging, notifications, ratings, and admin behavior remain deferred to their
approved milestones.

## Visual verification

The implemented screens were captured from an iPhone 11 Pro simulator at the
same 375 × 812 logical viewport. Reference and simulator states are combined in
`docs/design/qa/comparisons/` for side-by-side review. Source-side Figma comment
avatars remain visible in the reference crops but are not application UI.

The QA suite also captures the M1-only recovery and gate states for which no
unobscured client reference crop was available.
