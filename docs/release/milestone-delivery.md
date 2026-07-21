# Milestone delivery workflow

This project uses stable checkpoint delivery. The human repository owner is the
only person authorized to push to a remote.

1. Work only within the currently approved milestone.
2. Keep incomplete work in local commits until it is tested.
3. Stage explicit files or commits; do not use broad staging commands without
   reviewing the resulting diff.
4. Push only stable checkpoints selected by the human owner.
5. Demonstrate milestone completion with a build, recording, and acceptance
   checklist.
6. After milestone approval and payment confirmation, publish the final
   milestone commit and tag manually.
7. Do not begin the next milestone until the previous payment is received and
   the human owner explicitly approves the next scope.

Before any manual push, review:

```sh
git status --short
git diff --cached --stat
git diff --cached
```

The `.gitignore` protects secrets, generated output, and local artifacts. It
does not hide normal application source; unreleased source remains local by not
staging or pushing it.

## M1 external release inputs

The local iOS simulator app and Android debug APK can be built without client
credentials. A live M1 acceptance build additionally requires:

- Firebase Blaze billing and the console setup in `firebase/README.md`;
- final iOS bundle ID and Android application ID;
- Apple Developer and App Store Connect access for the human uploader;
- final iOS signing team, TestFlight app record, and build number;
- final app icon/launch assets if the client provides assets beyond Final Draft;
- platform Firebase App IDs, OAuth client IDs, and registered App Check
  providers in ignored local configuration.

The agent must not upload a TestFlight build, deploy Firebase, or publish code
without an explicit human request. Git publication remains human-only even when
other deployment steps are approved.
