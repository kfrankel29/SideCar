import assert from "node:assert/strict";
import test from "node:test";
import {
  canRequestGenderRestrictedRide,
  canMarkRiderNoShow,
  completedRideReimbursementCents,
  countsTowardCompletedRideReimbursement,
  calculateCheckoutAmounts,
  recordFailedPickupCodeAttempt,
  refundForRiderCancellation,
  validateRefundTiers,
} from "./booking_policy.js";

test("a rider can be marked no-show only after the full 10-minute wait", () => {
  const pickup = Date.UTC(2026, 8, 6, 15, 0);
  assert.equal(canMarkRiderNoShow(pickup, pickup + 9 * 60_000 + 59_999), false);
  assert.equal(canMarkRiderNoShow(pickup, pickup + 10 * 60_000), true);
});

test("only completed rides count toward total reimbursed", () => {
  assert.equal(countsTowardCompletedRideReimbursement("completed"), true);
  for (const status of [
    "confirmed",
    "in_progress",
    "cancelled",
    "refunded",
    "payout_held",
  ]) {
    assert.equal(countsTowardCompletedRideReimbursement(status), false);
  }
  assert.equal(completedRideReimbursementCents("completed", 4750, 5000), 4750);
  assert.equal(completedRideReimbursementCents("completed", undefined, 5000), 5000);
  assert.equal(completedRideReimbursementCents("cancelled", 4200, 5000), 0);
  assert.equal(completedRideReimbursementCents("completed", -1, 5000), 0);
});

test("pickup codes lock after exactly five failed attempts", () => {
  assert.deepEqual(recordFailedPickupCodeAttempt(undefined), {
    failedAttempts: 1,
    attemptsRemaining: 4,
    locked: false,
  });
  assert.deepEqual(recordFailedPickupCodeAttempt(3), {
    failedAttempts: 4,
    attemptsRemaining: 1,
    locked: false,
  });
  assert.deepEqual(recordFailedPickupCodeAttempt(4), {
    failedAttempts: 5,
    attemptsRemaining: 0,
    locked: true,
  });
  assert.deepEqual(recordFailedPickupCodeAttempt(20), {
    failedAttempts: 5,
    attemptsRemaining: 0,
    locked: true,
  });
});

test("women-only rides accept only a female rider profile", () => {
  assert.equal(canRequestGenderRestrictedRide("women_only", "Female"), true);
  assert.equal(canRequestGenderRestrictedRide("women_only", "female"), true);
  assert.equal(canRequestGenderRestrictedRide("women_only", "Male"), false);
  assert.equal(canRequestGenderRestrictedRide("women_only", undefined), false);
  assert.equal(canRequestGenderRestrictedRide("anyone", "Male"), true);
});

const checkoutPolicy = {
  serviceFeeType: "percentage" as const,
  serviceFeeValue: 5,
  driverFeePercentage: 5,
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
    serviceFeeCents: 250,
    driverPlatformFeeCents: 250,
    processingFeeCents: 188,
    creditAppliedCents: 0,
    totalCents: 5_438,
    driverPayoutCents: 4_750,
  });
});

test("bank checkout uses the configured percentage without a fixed fee", () => {
  const result = calculateCheckoutAmounts(5_000, checkoutPolicy, "bank");
  assert.equal(result.serviceFeeCents, 250);
  assert.equal(result.driverPlatformFeeCents, 250);
  assert.equal(result.processingFeeCents, 43);
  assert.equal(result.totalCents, 5_293);
});

test("zero Stripe percentage produces no rider processing fee", () => {
  const result = calculateCheckoutAmounts(5_000, {
    ...checkoutPolicy,
    cardRate: 0,
  });
  assert.deepEqual(result, {
    baseFareCents: 5_000,
    serviceFeeCents: 250,
    driverPlatformFeeCents: 250,
    processingFeeCents: 0,
    creditAppliedCents: 0,
    totalCents: 5_250,
    driverPayoutCents: 4_750,
  });
});

test("ride credit is automatically deducted while preserving Stripe minimum", () => {
  const result = calculateCheckoutAmounts(5_000, checkoutPolicy, "card", 500);
  assert.equal(result.creditAppliedCents, 500);
  assert.equal(result.totalCents, 4_938);
  assert.equal(result.driverPayoutCents, 4_750);

  const small = calculateCheckoutAmounts(100, {
    ...checkoutPolicy,
    serviceFeeValue: 0,
    cardRate: 0,
  }, "card", 500);
  assert.equal(small.creditAppliedCents, 50);
  assert.equal(small.totalCents, 50);
  assert.equal(small.driverPlatformFeeCents, 5);
  assert.equal(small.driverPayoutCents, 95);
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

test("normalized refund tiers omit optional undefined fields", () => {
  const tier = validateRefundTiers([{
    minimumHoursBeforeTrip: 0,
    minimumHoursExclusive: undefined,
    riderRefundPercentage: 100,
    platformPercentage: 0,
    driverPercentage: 0,
  }])[0]!;
  assert.equal(Object.hasOwn(tier, "minimumHoursExclusive"), false);
});
