import assert from "node:assert/strict";
import test from "node:test";
import {
  decodeGooglePolyline,
  pointInPolygon,
  proximityToRoute,
  routePointAllowed,
} from "./ride_routing.js";

test("decodes the standard Google encoded polyline", () => {
  assert.deepEqual(decodeGooglePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@"), [
    {latitude: 38.5, longitude: -120.2},
    {latitude: 40.7, longitude: -120.95},
    {latitude: 43.252, longitude: -126.453},
  ]);
});

test("measures distance and direction progress along a route", () => {
  const route = [
    {latitude: 34.40, longitude: -119.90},
    {latitude: 34.40, longitude: -119.80},
  ];
  const pickup = proximityToRoute(
    {latitude: 34.405, longitude: -119.88},
    route,
  );
  const dropoff = proximityToRoute(
    {latitude: 34.405, longitude: -119.82},
    route,
  );
  assert.ok(pickup.distanceMiles < 1);
  assert.ok(pickup.progress < dropoff.progress);
});

test("accepts the supplied boundary polygon as an explicit exception", () => {
  const boundary = [
    [-119.8767135, 34.4091842],
    [-119.8442695, 34.4047937],
    [-119.8389176, 34.4159824],
    [-119.853895, 34.4232043],
    [-119.8742798, 34.4229919],
    [-119.8767135, 34.4091842],
  ] as const;
  const point = {latitude: 34.414, longitude: -119.86};
  assert.equal(pointInPolygon(point, boundary), true);
  const result = routePointAllowed({
    point,
    route: [
      {latitude: 34.40, longitude: -119.95},
      {latitude: 34.40, longitude: -119.90},
    ],
    maximumDetourMiles: 1,
    boundaryExceptions: [boundary],
  });
  assert.equal(result.allowed, true);
  assert.equal(result.insideBoundaryException, true);
});

test("rejects a point beyond the configured route corridor", () => {
  const result = routePointAllowed({
    point: {latitude: 34.43, longitude: -119.85},
    route: [
      {latitude: 34.40, longitude: -119.90},
      {latitude: 34.40, longitude: -119.80},
    ],
    maximumDetourMiles: 1,
    boundaryExceptions: [],
  });
  assert.ok(result.distanceMiles > 1);
  assert.equal(result.allowed, false);
});
