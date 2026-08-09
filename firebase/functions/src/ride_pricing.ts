export type PricingMode = "driver_sets_under_cap" | "platform_calculated";

export interface RidePricingInput {
  distanceMeters: number;
  seatsAvailable: number;
  mileageRate: number;
  requestedPriceCents: number;
  mode: PricingMode;
}

export interface RidePricing {
  distanceMiles: number;
  maximumPriceCents: number;
  pricePerSeatCents: number;
}

const metersPerMile = 1609.344;

export function calculateRidePricing(input: RidePricingInput): RidePricing {
  if (!Number.isFinite(input.distanceMeters) || input.distanceMeters <= 0) {
    throw new Error("invalid-distance");
  }
  if (!Number.isInteger(input.seatsAvailable) || input.seatsAvailable < 1) {
    throw new Error("invalid-seats");
  }
  if (!Number.isFinite(input.mileageRate) || input.mileageRate <= 0) {
    throw new Error("invalid-mileage-rate");
  }
  if (!Number.isInteger(input.requestedPriceCents) || input.requestedPriceCents < 1) {
    throw new Error("invalid-price");
  }

  const distanceMiles = input.distanceMeters / metersPerMile;
  const maximumPriceCents = Math.floor(
    (input.mileageRate * distanceMiles * 100) / input.seatsAvailable,
  );
  if (maximumPriceCents < 1) throw new Error("price-cap-too-low");
  if (input.mode === "driver_sets_under_cap" &&
      input.requestedPriceCents > maximumPriceCents) {
    throw new Error("price-over-cap");
  }

  return {
    distanceMiles,
    maximumPriceCents,
    pricePerSeatCents: input.mode === "platform_calculated" ?
      maximumPriceCents :
      input.requestedPriceCents,
  };
}

export function luggageRank(value: string): number {
  switch (value) {
  case "backpack": return 0;
  case "one_suitcase": return 1;
  case "two_plus_bags": return 2;
  default: return -1;
  }
}

export function normalizeSearchText(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

export function locationMatches(locationText: string, searchText: string): boolean {
  const queryTokens = normalizeSearchText(searchText).split(" ").filter(Boolean);
  if (queryTokens.length === 0) return true;
  const candidate = normalizeSearchText(locationText);
  return queryTokens.every((token) => candidate.includes(token));
}

export function matchesDriverLanguage(
  driverLanguage: unknown,
  requiredLanguage: string,
): boolean {
  if (!requiredLanguage.trim()) return true;
  return normalizeSearchText(String(driverLanguage ?? "")) ===
    normalizeSearchText(requiredLanguage);
}
