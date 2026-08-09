import assert from "node:assert/strict";
import test from "node:test";
import {
  calculateCheckoutAmounts,
  refundForRiderCancellation,
  validateRefundTiers,
} from "./booking_policy.js";

const checkoutPolicy = {
  serviceFeeType: "percentage" as const,
  serviceFeeValue: 8,
  cardRate: 0.029,
  cardFixedCents: 30,
  bankRate: 0.008,
};

const refundTiers = [
  {minimumHoursBeforeTrip: 168, riderRefundPercentage: 100, platformPercentage: 0, driverPercentage: 0},
  {minimumHoursBeforeTrip: 24, minimumHoursExclusive: true, riderRefundPercentage: 50, platformPercentage: 8, driverPercentage: 42},
  {minimumHoursBeforeTrip: 0, riderRefundPercentage: 0, platformPercentage: 8, driverPercentage: 92},
];

test("checkout includes the configured service and card processing fees", () => {
  const result = calculateCheckoutAmounts(5_000, checkoutPolicy);
  assert.deepEqual(result, {
    baseFareCents: 5_000,
    serviceFeeCents: 400,
    processingFeeCents: 193,
    totalCents: 5_593,
    driverPayoutCents: 5_000,
  });
});

test("bank checkout uses the configured percentage without a fixed fee", () => {
  const result = calculateCheckoutAmounts(5_000, checkoutPolicy, "bank");
  assert.equal(result.serviceFeeCents, 400);
  assert.equal(result.processingFeeCents, 44);
  assert.equal(result.totalCents, 5_444);
});

test("refund policy selects full, partial, and no-refund tiers", () => {
  const now = Date.UTC(2026, 7, 8);
  assert.equal(refundForRiderCancellation(10_000, now + 8 * 24 * 3_600_000, now, refundTiers).riderRefundCents, 10_000);
  assert.deepEqual(
    refundForRiderCancellation(10_000, now + 3 * 24 * 3_600_000, now, refundTiers),
    {riderRefundCents: 5_000, platformCents: 800, driverCents: 4_200, tier: refundTiers[1]},
  );
  assert.equal(refundForRiderCancellation(10_000, now + 3_600_000, now, refundTiers).riderRefundCents, 0);
});

test("the 24-hour no-refund boundary is inclusive", () => {
  const now = Date.UTC(2026, 7, 8);
  const hour = 3_600_000;
  assert.equal(
    refundForRiderCancellation(10_000, now + 24 * hour, now, refundTiers).riderRefundCents,
    0,
  );
  assert.equal(
    refundForRiderCancellation(10_000, now + 24 * hour + 1, now, refundTiers).riderRefundCents,
    5_000,
  );
  assert.equal(
    refundForRiderCancellation(10_000, now + 168 * hour, now, refundTiers).riderRefundCents,
    10_000,
  );
});

test("invalid refund allocations fail closed", () => {
  assert.throws(
    () => validateRefundTiers([{minimumHoursBeforeTrip: 0, riderRefundPercentage: 50, platformPercentage: 8, driverPercentage: 41}]),
    /invalid-refund-allocation/,
  );
});
