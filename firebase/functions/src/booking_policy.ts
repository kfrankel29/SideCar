export type ServiceFeeType = "percentage" | "fixed";

export interface CheckoutPolicy {
  serviceFeeType: ServiceFeeType;
  serviceFeeValue: number;
  cardRate: number;
  cardFixedCents: number;
  bankRate: number;
}

export interface CheckoutAmounts {
  baseFareCents: number;
  serviceFeeCents: number;
  processingFeeCents: number;
  totalCents: number;
  driverPayoutCents: number;
}

export interface RefundTier {
  minimumHoursBeforeTrip: number;
  minimumHoursExclusive?: boolean;
  riderRefundPercentage: number;
  platformPercentage: number;
  driverPercentage: number;
}

export interface RefundAmounts {
  riderRefundCents: number;
  platformCents: number;
  driverCents: number;
  tier: RefundTier;
}

export interface PickupCodeAttempt {
  failedAttempts: number;
  attemptsRemaining: number;
  locked: boolean;
}

export function recordFailedPickupCodeAttempt(
  currentFailedAttempts: unknown,
  maximumAttempts = 5,
): PickupCodeAttempt {
  if (!Number.isInteger(maximumAttempts) || maximumAttempts < 1) {
    throw new Error("invalid-pickup-code-attempt-limit");
  }
  const current = typeof currentFailedAttempts === "number" &&
    Number.isFinite(currentFailedAttempts) ?
    Math.max(0, Math.floor(currentFailedAttempts)) : 0;
  const failedAttempts = Math.min(maximumAttempts, current + 1);
  return {
    failedAttempts,
    attemptsRemaining: maximumAttempts - failedAttempts,
    locked: failedAttempts >= maximumAttempts,
  };
}

export function canRequestGenderRestrictedRide(
  restriction: unknown,
  riderGender: unknown,
): boolean {
  if (restriction !== "women_only") return true;
  if (typeof riderGender !== "string") return false;
  const normalized = riderGender.trim().toLowerCase();
  return normalized === "female" || normalized === "woman" || normalized === "women";
}

function positiveInteger(value: number, name: string): number {
  if (!Number.isInteger(value) || value < 0) throw new Error(`invalid-${name}`);
  return value;
}

function percentage(value: number, name: string): number {
  if (!Number.isFinite(value) || value < 0 || value > 100) {
    throw new Error(`invalid-${name}`);
  }
  return value;
}

export function calculateCheckoutAmounts(
  baseFareCents: number,
  policy: CheckoutPolicy,
  paymentMethod: "card" | "bank" = "card",
): CheckoutAmounts {
  positiveInteger(baseFareCents, "base-fare");
  if (baseFareCents === 0) throw new Error("invalid-base-fare");
  percentage(policy.serviceFeeValue, "service-fee");
  percentage(policy.cardRate * 100, "card-rate");
  percentage(policy.bankRate * 100, "bank-rate");
  positiveInteger(policy.cardFixedCents, "card-fixed-fee");

  const serviceFeeCents = policy.serviceFeeType === "percentage" ?
    Math.round(baseFareCents * policy.serviceFeeValue / 100) :
    Math.round(policy.serviceFeeValue * 100);
  const providerRate = paymentMethod === "card" ? policy.cardRate : policy.bankRate;
  const providerFixedCents = paymentMethod === "card" ? policy.cardFixedCents : 0;
  if (providerRate >= 1) throw new Error("invalid-processing-rate");

  // Stripe calculates its percentage on the final charge, so gross up once.
  const totalCents = Math.ceil(
    (baseFareCents + serviceFeeCents + providerFixedCents) / (1 - providerRate),
  );
  return {
    baseFareCents,
    serviceFeeCents,
    processingFeeCents: totalCents - baseFareCents - serviceFeeCents,
    totalCents,
    driverPayoutCents: baseFareCents,
  };
}

export function validateRefundTiers(tiers: RefundTier[]): RefundTier[] {
  if (tiers.length === 0) throw new Error("missing-refund-tiers");
  const normalized = tiers.map((tier) => {
    if (!Number.isFinite(tier.minimumHoursBeforeTrip) ||
        tier.minimumHoursBeforeTrip < 0) {
      throw new Error("invalid-refund-window");
    }
    if (tier.minimumHoursExclusive !== undefined &&
        typeof tier.minimumHoursExclusive !== "boolean") {
      throw new Error("invalid-refund-boundary");
    }
    percentage(tier.riderRefundPercentage, "rider-refund");
    percentage(tier.platformPercentage, "platform-share");
    percentage(tier.driverPercentage, "driver-share");
    const total = tier.riderRefundPercentage +
      tier.platformPercentage + tier.driverPercentage;
    if (Math.abs(total - 100) > 0.001) throw new Error("invalid-refund-allocation");
    const {minimumHoursExclusive, ...required} = tier;
    return {
      ...required,
      ...(minimumHoursExclusive === undefined ? {} : {minimumHoursExclusive}),
    };
  });
  return normalized.sort(
    (left, right) => right.minimumHoursBeforeTrip - left.minimumHoursBeforeTrip,
  );
}

export function refundForRiderCancellation(
  totalCents: number,
  departureAtMillis: number,
  nowMillis: number,
  configuredTiers: RefundTier[],
): RefundAmounts {
  positiveInteger(totalCents, "charge-total");
  if (!Number.isFinite(departureAtMillis) || !Number.isFinite(nowMillis)) {
    throw new Error("invalid-refund-time");
  }
  const tiers = validateRefundTiers(configuredTiers);
  const hoursBeforeTrip = Math.max(0, departureAtMillis - nowMillis) / 3_600_000;
  const tier = tiers.find((candidate) => candidate.minimumHoursExclusive ?
    hoursBeforeTrip > candidate.minimumHoursBeforeTrip :
    hoursBeforeTrip >= candidate.minimumHoursBeforeTrip) ?? tiers.at(-1)!;
  const riderRefundCents = Math.round(totalCents * tier.riderRefundPercentage / 100);
  const platformCents = Math.round(totalCents * tier.platformPercentage / 100);
  return {
    riderRefundCents,
    platformCents,
    driverCents: totalCents - riderRefundCents - platformCents,
    tier,
  };
}
