import assert from "node:assert/strict";
import test from "node:test";

import {adminRideRecord} from "./admin_rides.js";

const timestamp = (value: string) => ({toDate: () => new Date(value)});

test("rides expose nested Google route names and operational fields", () => {
  assert.deepEqual(adminRideRecord("ride-1", {
    driverId: "driver-1",
    driverName: "Driver One",
    origin: {displayName: "Santa Barbara"},
    destination: {displayName: "San Francisco"},
    status: "published",
    departureAt: timestamp("2026-08-27T12:00:00.000Z"),
    seatsTotal: 4,
    seatsAvailable: 2,
    pricePerSeatCents: 6000,
    createdAt: timestamp("2026-08-01T12:00:00.000Z"),
    updatedAt: timestamp("2026-08-02T12:00:00.000Z"),
  }, [{id: "rider-1", name: "Rider One", status: "confirmed", seat: "front"}]), {
    id: "ride-1",
    driverId: "driver-1",
    driverName: "Driver One",
    originName: "Santa Barbara",
    destinationName: "San Francisco",
    status: "published",
    departureAt: "2026-08-27T12:00:00.000Z",
    seatsTotal: 4,
    seatsAvailable: 2,
    pricePerSeatCents: 6000,
    createdAt: "2026-08-01T12:00:00.000Z",
    updatedAt: "2026-08-02T12:00:00.000Z",
    riders: [{id: "rider-1", name: "Rider One", status: "confirmed", seat: "front"}],
  });
});

test("rides fall back to legacy route names without crashing", () => {
  const result = adminRideRecord("ride-legacy", {
    origin: {name: "Goleta"},
    destinationName: "San Mateo",
  });
  assert.equal(result.originName, "Goleta");
  assert.equal(result.destinationName, "San Mateo");
  assert.equal(result.departureAt, null);
  assert.equal(result.seatsTotal, 0);
  assert.deepEqual(result.riders, []);
});
