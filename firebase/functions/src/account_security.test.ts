import assert from "node:assert/strict";
import test from "node:test";
import {hasOpenAccountObligations} from "./account_security.js";

test("account deletion blocks open rides", () => {
  assert.equal(hasOpenAccountObligations(["open"], []), true);
  assert.equal(hasOpenAccountObligations(["in_progress"], []), true);
});

test("account deletion blocks unsettled booking states", () => {
  assert.equal(hasOpenAccountObligations([], ["payment_pending"]), true);
  assert.equal(hasOpenAccountObligations([], ["payout_held"]), true);
});

test("account deletion allows settled history", () => {
  assert.equal(
    hasOpenAccountObligations(
      ["completed", "cancelled"],
      ["completed", "refunded", "cancelled"],
    ),
    false,
  );
});
