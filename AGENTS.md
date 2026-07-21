# SideCar workspace instructions

These instructions apply to every automated coding or design agent working in this repository.

## Non-negotiable repository safety

- Never push to GitHub or any other Git remote. Only the human repository owner may push.
- Never run `git push`, create or update a pull request, publish a release, write through the GitHub API, change remote URLs, or configure automation that pushes code.
- Local inspection, edits, tests, staging, and local commits are allowed only when explicitly requested. A request to implement work never implies permission to publish it.
- Never commit credentials, Firebase service-account keys, signing keys, API secrets, `.env` files, or generated platform configuration containing secrets.

## Milestone boundary

- The active scope is Milestone 1 only: designs, Flutter/Firebase foundation, accounts, profile completion gating, password reset, and backend-controlled configuration.
- Do not implement later milestones without explicit human approval, even when future requirements influence today’s architecture.
- It is acceptable to create interfaces, extension points, and configuration models needed to avoid rework, but do not build later milestone behavior behind them.

## Product and design authority

- The source documents in `docs/source/` define product scope. The client’s live documents supersede these snapshots when they differ.
- The existing Figma file is the visual authority. Preserve existing screens. Add missing screens or states by duplicating the established visual patterns; do not redesign existing work unless the human owner explicitly approves it.
- Keep customer-facing artifacts professional and free of agent/tool boilerplate or generated-by markers.

## Architecture and quality

- Flutter is the shared iOS/Android client.
- Firebase is the initial backend platform. Values that the documents require to change without an app release must never be hardcoded as business rules in the client.
- Keep domain and data boundaries testable. Treat authentication, remote configuration, storage, and vendor integrations as replaceable adapters.
- Use feature-first modules, explicit error states, secure defaults, and automated tests proportional to risk.
- Do not advance a milestone until its acceptance criteria are testable and the client has approved the previous milestone.
