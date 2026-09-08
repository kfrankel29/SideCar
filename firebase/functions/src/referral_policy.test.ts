import assert from "node:assert/strict";
import test from "node:test";

import {
  normalizeReferralCode,
  referralCreditCents,
  validateReferralRedemption,
} from "./referral_policy.js";

test("referral codes are exactly five digits and preserve leading zeroes", () => {
  assert.equal(normalizeReferralCode(" 01234 "), "01234");
  for (const invalid of ["1234", "123456", "12A34", 12345, null]) {
    assert.throws(() => normalizeReferralCode(invalid), /invalid-referral-code/);
  }
});

test("referral redemption gives five dollars once and rejects self-referrals", () => {
  assert.equal(referralCreditCents, 500);
  assert.doesNotThrow(() => validateReferralRedemption("friend", "owner", ""));
  assert.throws(
    () => validateReferralRedemption("owner", "owner", ""),
    /own-referral-code/,
  );
  assert.throws(
    () => validateReferralRedemption("friend", "owner", "01234"),
    /referral-already-redeemed/,
  );
});
