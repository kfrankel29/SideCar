import assert from "node:assert/strict";
import test from "node:test";
import {
  decodeGooglePolyline,
  distanceMilesBetween,
  gasStationMatchesRoute,
  gasStationRouteMaximumMiles,
  pointMatchesRouteAndSearchArea,
  pointInPolygon,
  proximityToRoute,
  routePointAllowed,
  routeSearchMatch,
  searchRadiusMilesForPlace,
} from "./ride_routing.js";

test("city searches use a wider discovery corridor than exact stops", () => {
  assert.equal(searchRadiusMilesForPlace(["street_address"]), 1);
  assert.equal(searchRadiusMilesForPlace(["locality", "political"]), 12);
  assert.equal(searchRadiusMilesForPlace(["administrative_area_level_2"]), 22);
});

test("a same-direction ride through San Jose matches the city corridor", () => {
  const northboundRoute = [
    {latitude: 34.42, longitude: -119.70},
    {latitude: 36.60, longitude: -121.60},
    {latitude: 37.37, longitude: -121.95},
    {latitude: 37.77, longitude: -122.42},
  ];
  const sanJoseCenter = {latitude: 37.3382, longitude: -121.8863};
  const sanFrancisco = {latitude: 37.77, longitude: -122.42};

  assert.equal(routeSearchMatch({
    route: northboundRoute,
    pickup: sanJoseCenter,
    dropoff: sanFrancisco,
    pickupRadiusMiles: 1,
    dropoffRadiusMiles: 1,
    boundaryExceptions: [],
  }), false);
  assert.equal(routeSearchMatch({
    route: northboundRoute,
    pickup: sanJoseCenter,
    dropoff: sanFrancisco,
    pickupRadiusMiles: searchRadiusMilesForPlace(["locality"]),
    dropoffRadiusMiles: searchRadiusMilesForPlace(["locality"]),
    boundaryExceptions: [],
  }), true);
  assert.equal(routeSearchMatch({
    route: northboundRoute,
    pickup: sanFrancisco,
    dropoff: sanJoseCenter,
    pickupRadiusMiles: 12,
    dropoffRadiusMiles: 12,
    boundaryExceptions: [],
  }), false);
});

test("search-scoped gas stations must be near both the route and searched city", () => {
  const route = [
    {latitude: 37.40, longitude: -122.20},
    {latitude: 37.80, longitude: -122.50},
  ];
  const sanMateo = {latitude: 37.5630, longitude: -122.3255};
  const nearSanMateoRoute = {latitude: 37.57, longitude: -122.32};
  const farAlongSameRoute = {latitude: 37.78, longitude: -122.485};
  const offRoute = {latitude: 37.70, longitude: -121.90};

  assert.equal(pointMatchesRouteAndSearchArea({
    point: nearSanMateoRoute,
    route,
    searchAnchors: [sanMateo],
  }), true);
  assert.equal(pointMatchesRouteAndSearchArea({
    point: farAlongSameRoute,
    route,
    searchAnchors: [sanMateo],
    maximumSearchDistanceMiles: 5,
  }), false);
  assert.equal(pointMatchesRouteAndSearchArea({
    point: offRoute,
    route,
    searchAnchors: [sanMateo],
  }), false);
  assert.ok(distanceMilesBetween(sanMateo, nearSanMateoRoute) < 1);
});

test("gas station pins stay inside the half-mile route boundary", () => {
  const route = [
    {latitude: 37.30, longitude: -121.90},
    {latitude: 37.50, longitude: -121.90},
  ];
  const comfortablyInside = {latitude: 37.40, longitude: -121.892};
  const justOutsideHalfMile = {latitude: 37.40, longitude: -121.8905};

  assert.equal(gasStationRouteMaximumMiles, 0.5);
  assert.ok(proximityToRoute(comfortablyInside, route).distanceMiles < 0.5);
  assert.equal(gasStationMatchesRoute(comfortablyInside, route), true);
  assert.ok(proximityToRoute(justOutsideHalfMile, route).distanceMiles < 1);
  assert.ok(proximityToRoute(justOutsideHalfMile, route).distanceMiles > 0.5);
  assert.equal(gasStationMatchesRoute(justOutsideHalfMile, route), false);
});

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
