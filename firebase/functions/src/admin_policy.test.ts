import assert from "node:assert/strict";
import test from "node:test";

import {
  hasAdminClaim,
  parseAccountStatus,
  parseAdminBusinessConfig,
  parseInsuranceDecision,
} from "./admin_policy.js";

const validConfig = {
  serviceFeeType: "percentage",
  serviceFeeValue: 5,
  driverFeePercentage: 5,
  stripeCardPercentage: 2.9,
  irsMileageRate: 0.76,
  refundRules: [
    {minimumHoursBeforeTrip: 168, riderRefundPercentage: 100, platformPercentage: 0, driverPercentage: 0},
    {minimumHoursBeforeTrip: 24, riderRefundPercentage: 50, platformPercentage: 8, driverPercentage: 42},
    {minimumHoursBeforeTrip: 0, riderRefundPercentage: 0, platformPercentage: 8, driverPercentage: 92},
  ],
  paymentExpirationHours: 24,
  tripAutoCompleteHours: 48,
};

test("admin access requires the explicit custom claim", () => {
  assert.equal(hasAdminClaim({admin: true}), true);
  assert.equal(hasAdminClaim({admin: false}), false);
  assert.equal(hasAdminClaim({role: "admin"}), false);
  assert.equal(hasAdminClaim(undefined), false);
});

test("admin config accepts and normalizes every M6 business value", () => {
  const config = parseAdminBusinessConfig(validConfig);
  assert.equal(config.serviceFeeType, "percentage");
  assert.equal(config.serviceFeeValue, 5);
  assert.equal(config.driverFeePercentage, 5);
  assert.equal(config.stripeCardPercentage, 2.9);
  assert.equal(config.irsMileageRate, 0.76);
  assert.equal(config.paymentExpirationHours, 24);
  assert.equal(config.tripAutoCompleteHours, 48);
  assert.deepEqual(config.refundRules.map((rule) => rule.minimumHoursBeforeTrip), [168, 24, 0]);
});

test("admin config rejects unsafe fees, durations, and refund allocations", () => {
  assert.throws(
    () => parseAdminBusinessConfig({...validConfig, serviceFeeValue: 101}),
    /invalid-service-fee-value/,
  );
  assert.throws(
    () => parseAdminBusinessConfig({...validConfig, driverFeePercentage: 101}),
    /invalid-driver-fee-percentage/,
  );
  assert.throws(
    () => parseAdminBusinessConfig({...validConfig, stripeCardPercentage: 100}),
    /invalid-stripe-card-percentage/,
  );
  assert.throws(
    () => parseAdminBusinessConfig({...validConfig, paymentExpirationHours: 0}),
    /invalid-payment-expiration-hours/,
  );
  assert.throws(
    () => parseAdminBusinessConfig({
      ...validConfig,
      refundRules: [{minimumHoursBeforeTrip: 0, riderRefundPercentage: 50, platformPercentage: 8, driverPercentage: 41}],
    }),
    /invalid-refund-allocation/,
  );
});

test("admin decisions are limited to supported state transitions", () => {
  assert.equal(parseAccountStatus("active"), "active");
  assert.equal(parseAccountStatus("suspended"), "suspended");
  assert.equal(parseAccountStatus("banned"), "banned");
  assert.throws(() => parseAccountStatus("deleted"), /invalid-account-status/);
  assert.equal(parseInsuranceDecision("verified"), "verified");
  assert.equal(parseInsuranceDecision("rejected"), "rejected");
  assert.throws(() => parseInsuranceDecision("pending"), /invalid-insurance-decision/);
});
