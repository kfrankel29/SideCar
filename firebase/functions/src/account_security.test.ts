import assert from "node:assert/strict";
import test from "node:test";
import {hasOpenAccountObligations} from "./account_security.js";

test("account deletion blocks open rides", () => {
  assert.equal(hasOpenAccountObligations(["in_progress"], []), true);
});

test("account deletion ignores orphaned legacy states without a departure", () => {
  assert.equal(hasOpenAccountObligations(["open", "published"], []), false);
  assert.equal(hasOpenAccountObligations([], ["pending_driver", "confirmed"]), false);
});

test("account deletion blocks unsettled booking states", () => {
  assert.equal(hasOpenAccountObligations([], ["payment_processing"]), true);
  assert.equal(hasOpenAccountObligations([], ["completion_processing"]), true);
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
  assert.equal(
    hasOpenAccountObligations([], ["requested", "accepted", "payment_pending"]),
    false,
  );
});

test("account deletion blocks current published trips", () => {
  const now = Date.parse("2026-09-12T12:00:00.000Z");
  assert.equal(
    hasOpenAccountObligations(
      [{status: "published", departureAt: "2026-09-12T13:00:00.000Z"}],
      [],
      now,
    ),
    true,
  );
});

test("account deletion ignores stale operational trip states", () => {
  const now = Date.parse("2026-09-12T12:00:00.000Z");
  assert.equal(
    hasOpenAccountObligations(
      [{status: "open", departureAt: "2026-09-10T10:00:00.000Z"}],
      [{status: "confirmed", departureAt: "2026-09-10T10:00:00.000Z"}],
      now,
    ),
    false,
  );
});

test("account deletion still blocks unresolved financial processing", () => {
  const now = Date.parse("2026-09-12T12:00:00.000Z");
  assert.equal(
    hasOpenAccountObligations(
      [],
      [{status: "payment_processing", departureAt: "2026-09-01T10:00:00.000Z"}],
      now,
    ),
    true,
  );
});
