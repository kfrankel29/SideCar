# Architecture decisions

## ADR-001: Flutter client with Firebase backend

Status: accepted for Milestone 1.

Use Flutter for the iOS and Android application. Milestone 1 uses Firebase
Authentication, Cloud Firestore, Cloud Storage, Remote Config, App Check, and
Cloud Functions where server-side enforcement is required. Crash reporting is
enabled after the final platform Firebase apps and store identifiers are
registered.

Business-critical configuration is read from a server-owned configuration model. Remote Config may distribute safe client-facing values, but authorization and financial rules must also be enforced by trusted server code in the milestone that executes those rules.

## ADR-002: Messaging direction

Status: recommendation only; implementation is deferred to Milestone 5.

Use Cloud Firestore real-time listeners and Firebase Cloud Messaging rather than operating a custom WebSocket service for the launch version. This keeps the initial operational surface small while preserving a path to partitioning, denormalized inbox records, retention policies, and a dedicated service if traffic or product requirements later justify it.

## ADR-003: Repository publication

Status: mandatory.

Automated agents may not push or publish repository content. Only the human repository owner may perform remote Git operations.
