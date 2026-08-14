import test from "node:test";
import assert from "node:assert/strict";
import {
  cumulativeArrivalSeconds,
  googleWaypoint,
  parseOptimizedRoute,
} from "./live_trip_route.js";

test("uses Google's optimized order and cumulative leg durations", () => {
  const route = parseOptimizedRoute({
    routes: [{
      optimizedIntermediateWaypointIndex: [2, 0, 1],
      legs: [{duration: "600s"}, {duration: "300.4s"}, {duration: "120s"}],
      polyline: {encodedPolyline: "encoded"},
    }],
  }, 3);
  assert.deepEqual(route.orderedIndexes, [2, 0, 1]);
  assert.deepEqual(cumulativeArrivalSeconds(route, 3), [600, 900, 1020]);
  assert.equal(route.encodedPolyline, "encoded");
});

test("keeps request order if Google omits an optimized order", () => {
  const route = parseOptimizedRoute({routes: [{legs: []}]}, 2);
  assert.deepEqual(route.orderedIndexes, [0, 1]);
});

test("prefers place IDs and falls back to coordinates", () => {
  assert.deepEqual(googleWaypoint({placeId: "abc", latitude: 1, longitude: 2}), {
    placeId: "abc",
  });
  assert.deepEqual(googleWaypoint({placeId: "", latitude: 1, longitude: 2}), {
    location: {latLng: {latitude: 1, longitude: 2}},
  });
});
