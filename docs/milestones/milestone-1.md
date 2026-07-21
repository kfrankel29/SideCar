# Milestone 1 — Designs, Foundation, Accounts, and Remote Config

Status: **active**  
Target: **July 24, 2026**  
Design gap list target: **July 18, 2026**

## Design deliverables

- Use the client Figma **Final Draft** page as the sole visual authority.
- Audit the Final Draft comments as interaction and sequence requirements.
- Implement the approved M1 screens and missing states without editing the client file.
- Keep later-milestone screens and behavior out of this delivery.

## Development deliverables

- Flutter project for iOS and Android.
- Firebase-backed architecture recommendation and messaging decision.
- Backend-controlled configuration for:
  - service fee amount and fee type;
  - IRS mileage rate;
  - refund percentages and time windows;
  - accepted-request payment expiration;
  - trip auto-complete window;
  - allowed school email domains.
- Account creation restricted by the backend-controlled allowed-domain list.
- Six-digit email-code password reset followed by new-password entry.
- Required profile creation with gallery/camera profile photo.
- Ride actions gated until profile completion.

## Acceptance criteria

- Final Draft is confirmed by the client as the current design source.
- A testable iOS TestFlight build and Android APK/internal-test build are available.
- On a real device, the client can:
  - create an account using `ucsb.edu`;
  - see other domains, including other `.edu` domains, rejected;
  - reset a password with a six-digit email code;
  - complete the required profile;
  - observe a backend configuration change in the app without installing a new build.

## Explicitly deferred

Verification vendors, ride posting/search, booking/payments, live messaging, notifications, ratings, admin tools, and store submission are not implemented until their milestones are approved.
