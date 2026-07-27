import assert from "node:assert/strict";
import test from "node:test";
import {
  stripeIdentitySessionUid,
  stripeIdentityStatusForEvent,
} from "./stripe_identity.js";

test("maps the complete Stripe Identity lifecycle", () => {
  assert.equal(
    stripeIdentityStatusForEvent("identity.verification_session.created"),
    "pending",
  );
  assert.equal(
    stripeIdentityStatusForEvent("identity.verification_session.processing"),
    "pending",
  );
  assert.equal(
    stripeIdentityStatusForEvent("identity.verification_session.verified"),
    "verified",
  );
  assert.equal(
    stripeIdentityStatusForEvent(
      "identity.verification_session.requires_input",
    ),
    "requiresAction",
  );
  assert.equal(
    stripeIdentityStatusForEvent("identity.verification_session.canceled"),
    "failed",
  );
  assert.equal(
    stripeIdentityStatusForEvent("identity.verification_session.redacted"),
    "notStarted",
  );
});

test("resolves the Firebase user from protected Stripe references", () => {
  assert.equal(
    stripeIdentitySessionUid({
      metadata: {uid: "metadata-user"},
      client_reference_id: "reference-user",
    }),
    "metadata-user",
  );
  assert.equal(
    stripeIdentitySessionUid({client_reference_id: "reference-user"}),
    "reference-user",
  );
  assert.equal(stripeIdentitySessionUid({metadata: {}}), null);
});
