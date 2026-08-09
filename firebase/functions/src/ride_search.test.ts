import assert from "node:assert/strict";
import test from "node:test";
import {
  compareClosestDepartures,
  distanceFromDateWindow,
} from "./ride_search.js";

test("a departure inside the requested day has no distance", () => {
  assert.equal(distanceFromDateWindow(150, 100, 200), 0);
});

test("distance is measured from the nearest requested-day boundary", () => {
  assert.equal(distanceFromDateWindow(90, 100, 200), 10);
  assert.equal(distanceFromDateWindow(215, 100, 200), 15);
});

test("closest departures sort by proximity then departure time", () => {
  const values = [250, 80, 220, 90];
  values.sort((left, right) =>
    compareClosestDepartures(left, right, 100, 200));
  assert.deepEqual(values, [90, 80, 220, 250]);
});
