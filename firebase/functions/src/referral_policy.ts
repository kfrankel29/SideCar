export const referralCreditCents = 500;

export function normalizeReferralCode(value: unknown): string {
  if (typeof value !== "string" || !/^\d{5}$/.test(value.trim())) {
    throw new Error("invalid-referral-code");
  }
  return value.trim();
}

export function validateReferralRedemption(
  redeemerUid: string,
  ownerUid: string,
  alreadyRedeemed: unknown,
): void {
  if (!ownerUid) throw new Error("missing-referral-owner");
  if (ownerUid === redeemerUid) throw new Error("own-referral-code");
  if (typeof alreadyRedeemed === "string" && alreadyRedeemed.trim()) {
    throw new Error("referral-already-redeemed");
  }
}
