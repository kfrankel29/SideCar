# SideCar

Cross-platform rideshare/cost-sharing application for iOS and Android, built with Flutter and Firebase.

The repository is currently limited to **Milestone 1**. See [Milestone 1 scope](docs/milestones/milestone-1.md) for the active deliverables and acceptance criteria.

## Workspace layout

- `apps/mobile/` — Flutter application for iOS and Android.
- `apps/admin/` — reserved for the later admin milestone; no admin features are implemented during Milestone 1.
- `firebase/` — Firebase configuration, rules, indexes, Remote Config defaults, and server-side functions when required.
- `docs/` — source documents, milestone scope, decisions, and design-gap tracking.

Final Draft implementation evidence is recorded in [design QA](design-qa.md)
and the [M1 Final Draft audit](docs/design/final-draft-m1-audit.md). Firebase
console and deployment prerequisites are documented in
[Firebase setup](firebase/README.md).

The iOS bundle identifier and Android application ID are both
`com.kaileefrankel.sidecar`. Use this identifier for Firebase and store records.

## Publication policy

Automated agents must never push this repository or create pull requests. Only the human repository owner publishes code.

See [milestone delivery workflow](docs/release/milestone-delivery.md) for the
stable-checkpoint and payment handoff process.
