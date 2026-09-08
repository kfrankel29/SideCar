import assert from "node:assert/strict";
import test from "node:test";

import {
  adminAccountRecord,
  manualVerificationEmail,
  parseAdminProfileUpdate,
} from "./admin_accounts.js";

const timestamp = (value: string) => ({toDate: () => new Date(value)});

test("accounts expose moderation and all verification states", () => {
  const result = adminAccountRecord(
    {
      uid: "user-1",
      email: "rider@example.com",
      emailVerified: true,
      disabled: true,
      customClaims: {admin: false},
    },
    {
      firstName: "Rider",
      lastName: "One",
      age: 20,
      gender: "Female",
      school: "UC Santa Barbara",
      primaryRole: "rider",
      profileComplete: true,
      accountStatus: "suspended",
      suspensionReason: "Manual QA suspension",
      photoUrl: "https://example.com/photo.jpg",
      createdAt: timestamp("2026-08-01T12:00:00.000Z"),
      updatedAt: timestamp("2026-08-02T12:00:00.000Z"),
    },
    {
      identityStatus: "verified",
      insuranceStatus: "pendingManualReview",
      insuranceVerificationProvider: "manual",
      manualInsuranceSubmitted: true,
      insuranceDocumentPath: "users/user-1/verification/insurance/current.pdf",
      insuranceReviewReason: "Needs review",
      updatedAt: timestamp("2026-08-03T12:00:00.000Z"),
    },
    {complete: true},
  );

  assert.deepEqual(result, {
    uid: "user-1",
    email: "rider@example.com",
    emailVerified: true,
    disabled: true,
    isAdmin: false,
    firstName: "Rider",
    lastName: "One",
    age: 20,
    gender: "Female",
    school: "UC Santa Barbara",
    primaryRole: "rider",
    profileComplete: true,
    accountStatus: "suspended",
    suspensionReason: "Manual QA suspension",
    photoUrl: "https://example.com/photo.jpg",
    createdAt: "2026-08-01T12:00:00.000Z",
    updatedAt: "2026-08-02T12:00:00.000Z",
    verification: {
      identityStatus: "verified",
      driverStatus: "verified",
      insuranceStatus: "pendingManualReview",
      insuranceProvider: "manual",
      manualInsuranceSubmitted: true,
      insuranceDocumentAvailable: true,
      insuranceReviewReason: "Needs review",
      updatedAt: "2026-08-03T12:00:00.000Z",
    },
  });
});

test("admin profile updates enforce adult UCSB accounts", () => {
  const value = parseAdminProfileUpdate({
    firstName: " Jordan ",
    lastName: " Lee ",
    email: "JORDAN@UCSB.EDU",
    age: 21,
    gender: "Non-binary",
    school: "UC Santa Barbara",
    primaryRole: "driver",
  });
  assert.equal(value.email, "jordan@ucsb.edu");
  assert.equal(value.firstName, "Jordan");
  assert.throws(() => parseAdminProfileUpdate({...value, age: 17}), /age-invalid/);
  assert.throws(
    () => parseAdminProfileUpdate({...value, email: "jordan@example.com"}),
    /email-invalid/,
  );
});

test("manual admin verification supports valid exception accounts", () => {
  assert.equal(
    manualVerificationEmail(" QA.User+review@Example.COM "),
    "qa.user+review@example.com",
  );
  assert.throws(() => manualVerificationEmail("not-an-email"), /email-invalid/);
  assert.throws(() => manualVerificationEmail(""), /email-invalid/);
});

test("accounts use safe defaults for incomplete profiles", () => {
  const result = adminAccountRecord(
    {uid: "admin-1", emailVerified: false, disabled: false, customClaims: {admin: true}},
    undefined,
    {lastError: "Upload required"},
    undefined,
  );

  assert.equal(result.email, "");
  assert.equal(result.isAdmin, true);
  assert.equal(result.accountStatus, "active");
  assert.equal(result.profileComplete, false);
  assert.deepEqual(result.verification, {
    identityStatus: "notStarted",
    driverStatus: "notStarted",
    insuranceStatus: "notStarted",
    insuranceProvider: "",
    manualInsuranceSubmitted: false,
    insuranceDocumentAvailable: false,
    insuranceReviewReason: "Upload required",
    updatedAt: null,
  });
});
