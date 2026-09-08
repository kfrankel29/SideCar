# SideCar admin application

Milestone 6 is served from Firebase Hosting at `/admin/` and uses Firebase
Authentication plus an explicit `admin: true` custom claim. The browser never
reads Firestore directly. It calls the secured `admin*` Cloud Functions for:

- identity and driver verification status;
- user suspension, banning, and restoration;
- live Remote Config business settings;
- ride, booking, payment, refund, dispute, and audit views.

Every mutation writes an immutable entry to `admin_audit_logs`. Business config
publishes a new `config_version` marker so the mobile app can confirm that it
activated the latest values without requiring a new build.
