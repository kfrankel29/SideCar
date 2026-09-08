import {
  RefundTier,
  ServiceFeeType,
  validateRefundTiers,
} from "./booking_policy.js";

export type AccountStatus = "active" | "suspended" | "banned";
export type InsuranceDecision = "verified" | "rejected";

export interface AdminBusinessConfig {
  serviceFeeType: ServiceFeeType;
  serviceFeeValue: number;
  driverFeePercentage: number;
  stripeCardPercentage: number;
  irsMileageRate: number;
  refundRules: RefundTier[];
  paymentExpirationHours: number;
  tripAutoCompleteHours: number;
}

type Json = Record<string, unknown>;

export function hasAdminClaim(token: Json | undefined): boolean {
  return token?.admin === true;
}

function object(value: unknown, field: string): Json {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`invalid-${field}`);
  }
  return value as Json;
}

function finiteNumber(
  value: unknown,
  field: string,
  minimum: number,
  maximum: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value) ||
      value < minimum || value > maximum) {
    throw new Error(`invalid-${field}`);
  }
  return value;
}

function positiveInteger(value: unknown, field: string, maximum: number): number {
  const parsed = finiteNumber(value, field, 1, maximum);
  if (!Number.isInteger(parsed)) throw new Error(`invalid-${field}`);
  return parsed;
}

export function parseAccountStatus(value: unknown): AccountStatus {
  if (value === "active" || value === "suspended" || value === "banned") {
    return value;
  }
  throw new Error("invalid-account-status");
}

export function parseInsuranceDecision(value: unknown): InsuranceDecision {
  if (value === "verified" || value === "rejected") return value;
  throw new Error("invalid-insurance-decision");
}

export function parseAdminBusinessConfig(value: unknown): AdminBusinessConfig {
  const data = object(value, "admin-config");
  if (data.serviceFeeType !== "percentage" && data.serviceFeeType !== "fixed") {
    throw new Error("invalid-service-fee-type");
  }
  const serviceFeeMaximum = data.serviceFeeType === "percentage" ? 100 : 1_000;
  const rulesValue = data.refundRules;
  if (!Array.isArray(rulesValue)) throw new Error("invalid-refund-rules");
  const refundRules = validateRefundTiers(rulesValue.map((value) => {
    const rule = object(value, "refund-rule");
    if (rule.minimumHoursExclusive !== undefined &&
        typeof rule.minimumHoursExclusive !== "boolean") {
      throw new Error("invalid-refund-boundary");
    }
    return {
      minimumHoursBeforeTrip: finiteNumber(
        rule.minimumHoursBeforeTrip,
        "refund-window",
        0,
        24 * 365,
      ),
      ...(rule.minimumHoursExclusive === undefined ? {} : {
        minimumHoursExclusive: rule.minimumHoursExclusive as boolean,
      }),
      riderRefundPercentage: finiteNumber(
        rule.riderRefundPercentage,
        "rider-refund",
        0,
        100,
      ),
      platformPercentage: finiteNumber(
        rule.platformPercentage,
        "platform-refund-share",
        0,
        100,
      ),
      driverPercentage: finiteNumber(
        rule.driverPercentage,
        "driver-refund-share",
        0,
        100,
      ),
    };
  }));
  return {
    serviceFeeType: data.serviceFeeType,
    serviceFeeValue: finiteNumber(
      data.serviceFeeValue,
      "service-fee-value",
      0,
      serviceFeeMaximum,
    ),
    driverFeePercentage: finiteNumber(
      data.driverFeePercentage,
      "driver-fee-percentage",
      0,
      100,
    ),
    stripeCardPercentage: finiteNumber(
      data.stripeCardPercentage,
      "stripe-card-percentage",
      0,
      99,
    ),
    irsMileageRate: finiteNumber(data.irsMileageRate, "irs-mileage-rate", 0, 10),
    refundRules,
    paymentExpirationHours: positiveInteger(
      data.paymentExpirationHours,
      "payment-expiration-hours",
      24 * 30,
    ),
    tripAutoCompleteHours: positiveInteger(
      data.tripAutoCompleteHours,
      "trip-auto-complete-hours",
      24 * 30,
    ),
  };
}
