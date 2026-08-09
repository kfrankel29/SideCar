import assert from "node:assert/strict";
import test from "node:test";
import {
  calculateRidePricing,
  locationMatches,
  luggageRank,
  matchesDriverLanguage,
} from "./ride_pricing.js";

test("calculates and floors the server price cap", () => {
  const pricing = calculateRidePricing({
    distanceMeters: 100 * 1609.344,
    seatsAvailable: 2,
    mileageRate: 0.76,
    requestedPriceCents: 3800,
    mode: "driver_sets_under_cap",
  });

  assert.equal(pricing.maximumPriceCents, 3800);
  assert.equal(pricing.pricePerSeatCents, 3800);
});

test("rejects a driver price above the server cap", () => {
  assert.throws(
    () => calculateRidePricing({
      distanceMeters: 100 * 1609.344,
      seatsAvailable: 2,
      mileageRate: 0.76,
      requestedPriceCents: 3801,
      mode: "driver_sets_under_cap",
    }),
    /price-over-cap/,
  );
});

test("platform calculated mode ignores the requested display value", () => {
  const pricing = calculateRidePricing({
    distanceMeters: 50 * 1609.344,
    seatsAvailable: 1,
    mileageRate: 0.70,
    requestedPriceCents: 1,
    mode: "platform_calculated",
  });

  assert.equal(pricing.pricePerSeatCents, 3500);
});

test("location and luggage filters normalize user input", () => {
  assert.equal(locationMatches("UCSB / Isla Vista, California", "isla vista"), true);
  assert.equal(locationMatches("Palo Alto — Caltrain", "San Jose"), false);
  assert.ok(luggageRank("two_plus_bags") > luggageRank("one_suitcase"));
});

test("spoken language filter is optional and case insensitive", () => {
  assert.equal(matchesDriverLanguage("English", "english"), true);
  assert.equal(matchesDriverLanguage("Spanish", "English"), false);
  assert.equal(matchesDriverLanguage(undefined, ""), true);
});
