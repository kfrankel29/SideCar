import assert from "node:assert/strict";
import test from "node:test";
import {weeklyDepartures} from "./ride_recurrence.js";

test("weekly departures preserve seven-day intervals", () => {
  const values = weeklyDepartures(new Date("2026-08-07T22:00:00.000Z"), 3);
  assert.deepEqual(values.map((value) => value.toISOString()), [
    "2026-08-07T22:00:00.000Z",
    "2026-08-14T22:00:00.000Z",
    "2026-08-21T22:00:00.000Z",
  ]);
});

test("weekly departures reject unsafe occurrence counts", () => {
  assert.throws(() => weeklyDepartures(new Date(), 0), /invalid-occurrences/);
  assert.throws(() => weeklyDepartures(new Date(), 27), /invalid-occurrences/);
});
