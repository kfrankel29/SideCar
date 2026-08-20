import test from "node:test";
import assert from "node:assert/strict";

import {
  authEmailEnvelope,
  defaultAuthEmailReplyTo,
  defaultAuthEmailSender,
} from "./auth_email.js";

test("authentication email uses the ride-sidecar verification sender", () => {
  const email = authEmailEnvelope({
    to: "student@ucsb.edu",
    subject: "Verify your SideCar email",
    text: "Verification code",
    html: "<p>Verification code</p>",
  });
  assert.equal(email.from, defaultAuthEmailSender);
  assert.equal(email.replyTo, defaultAuthEmailReplyTo);
});

test("authentication email accepts a backend-configured sender", () => {
  const email = authEmailEnvelope({
    to: "student@ucsb.edu",
    sender: "SideCar Test <verify-test@ride-sidecar.com>",
    subject: "Verify",
    text: "Code",
    html: "<p>Code</p>",
  });
  assert.equal(email.from, "SideCar Test <verify-test@ride-sidecar.com>");
});
