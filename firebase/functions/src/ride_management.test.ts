import assert from "node:assert/strict";
import test from "node:test";
import {
  availableSeatsAfterUpdate,
  bookedSeatCount,
  isPriceWithinLimit,
  publicSeatInventory,
  rideIntervalsOverlap,
} from "./ride_management.js";

test("preserves booked seats when capacity changes", () => {
  assert.equal(bookedSeatCount(4, 2), 2);
  assert.equal(availableSeatsAfterUpdate(4, 2, 5), 3);
});

test("rejects capacity below the number of booked seats", () => {
  assert.equal(availableSeatsAfterUpdate(4, 1, 2), null);
});

test("does not infer negative booked seats from inconsistent legacy data", () => {
  assert.equal(bookedSeatCount(3, 5), 0);
  assert.equal(availableSeatsAfterUpdate(3, 5, 4), 4);
});

test("cancelled rides expose refunded seats as open and none as booked", () => {
  assert.deepEqual(publicSeatInventory("cancelled", 3, 0, 3), {
    seatsTotal: 3,
    seatsAvailable: 3,
    bookedSeats: 0,
  });
});

test("published ride inventory remains bounded", () => {
  assert.deepEqual(publicSeatInventory("published", 3, -2, 8), {
    seatsTotal: 3,
    seatsAvailable: 0,
    bookedSeats: 3,
  });
});

test("enforces a stored route price cap", () => {
  assert.equal(isPriceWithinLimit(7600, 7600), true);
  assert.equal(isPriceWithinLimit(7601, 7600), false);
  assert.equal(isPriceWithinLimit(7601, 0), true);
});

test("detects overlapping driver ride intervals", () => {
  const hour = 60 * 60 * 1000;
  assert.equal(rideIntervalsOverlap(0, 7200, hour, 1800), true);
  assert.equal(rideIntervalsOverlap(0, 3600, hour, 1800), false);
  assert.equal(rideIntervalsOverlap(hour, 1800, 0, 3600), false);
});
