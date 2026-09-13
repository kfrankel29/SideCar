# SideCar controlled CI/CD

The GitHub Actions pipeline is deliberately manual-only. Normal pushes and pull
requests do not start a paid runner.

From **Actions → SideCar manual pipeline → Run workflow**:

- `verify` runs the complete Firebase Functions and Flutter analyze/test suite.
- `deploy-backend` runs the same checks first, then deploys Functions and
  Firestore rules only when `production_confirmation` is exactly
  `deploy sidecar production`.

The repository environment named `production` should require approval. Its only
required secret is `FIREBASE_SERVICE_ACCOUNT_JSON`, containing a narrowly scoped
Google service account credential allowed to deploy this Firebase project.

App Store Connect and Google Play builds remain a separate, deliberate release
step. This workflow never uploads a store build or submits an app for review.
