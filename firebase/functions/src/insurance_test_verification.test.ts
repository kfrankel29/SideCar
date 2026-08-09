import assert from "node:assert/strict";
import test from "node:test";
import {insuranceTestVerificationEligibility} from "./insurance_test_verification.js";

const allowedTestEmails = new Set(["driver@example.com"]);

test("allows a fully prepared allow-listed test driver", () => {
  assert.deepEqual(
    insuranceTestVerificationEligibility({
      email: " Driver@Example.com ",
      emailVerified: true,
      schoolEmailVerified: false,
      allowedTestEmails,
      identityStatus: "verified",
      vehicleComplete: true,
    }),
    {allowed: true},
  );
});

test("rejects non-test users and incomplete verification prerequisites", () => {
  const base = {
    email: "driver@example.com",
    emailVerified: true,
    schoolEmailVerified: false,
    allowedTestEmails,
    identityStatus: "verified",
    vehicleComplete: true,
  };
  assert.deepEqual(
    insuranceTestVerificationEligibility({...base, email: "student@ucsb.edu"}),
    {allowed: false, reason: "email"},
  );
  assert.deepEqual(
    insuranceTestVerificationEligibility({...base, identityStatus: "pending"}),
    {allowed: false, reason: "identity"},
  );
  assert.deepEqual(
    insuranceTestVerificationEligibility({...base, vehicleComplete: false}),
    {allowed: false, reason: "vehicle"},
  );
});
