import assert from "node:assert/strict";
import test from "node:test";
import {
  compactEncodedPolyline,
  googleStaticMapUrl,
  rideMapPreviewUrl,
  rideStopMapPreviewUrl,
} from "./ride_map_preview.js";

test("builds a cached public map-preview URL without a credential", () => {
  const value = rideMapPreviewUrl("ride/with spaces", "encoded-route");
  const url = new URL(value);

  assert.equal(url.origin, "https://sidecar-fb0e7.web.app");
  assert.equal(url.pathname, "/ride-map");
  assert.equal(url.searchParams.get("id"), "ride/with spaces");
  assert.match(url.searchParams.get("v") ?? "", /^5-[a-f0-9]{12}$/);
  assert.equal(value.includes("key="), false);
});

test("compacts long route geometry for the Static Maps URL limit", () => {
  const segment = "_p~iF~ps|U_ulLnnqC_mqNvxq`@";
  const longRoute = segment.repeat(1_500);
  const compacted = compactEncodedPolyline(longRoute, 4_000);

  assert.ok(compacted.length > 0);
  assert.ok(compacted.length <= 4_000);
  assert.notEqual(compacted, longRoute);
});

test("keeps already compact route geometry unchanged", () => {
  const route = "_p~iF~ps|U_ulLnnqC_mqNvxq`@";
  assert.equal(compactEncodedPolyline(route), route);
});

test("changes the map cache key only when the route changes", () => {
  const first = new URL(rideMapPreviewUrl("ride-1", "route-a"));
  const same = new URL(rideMapPreviewUrl("ride-1", "route-a"));
  const changed = new URL(rideMapPreviewUrl("ride-1", "route-b"));

  assert.equal(first.searchParams.get("v"), same.searchParams.get("v"));
  assert.notEqual(first.searchParams.get("v"), changed.searchParams.get("v"));
});

test("builds a monochrome Google static map containing the real route", () => {
  const value = googleStaticMapUrl({
    apiKey: "server-secret",
    encodedPolyline: "encoded-route",
    origin: {latitude: 34.4, longitude: -119.8},
    destination: {latitude: 37.6, longitude: -122.4},
  });
  const url = new URL(value);

  assert.equal(url.hostname, "maps.googleapis.com");
  assert.equal(url.searchParams.get("key"), "server-secret");
  assert.equal(url.searchParams.get("size"), "640x352");
  assert.equal(url.searchParams.get("scale"), "2");
  assert.ok(Number.isFinite(Number(url.searchParams.get("zoom"))));
  assert.match(url.searchParams.get("center") ?? "", /^-?[\d.]+,-?[\d.]+$/);
  assert.match(url.searchParams.get("path") ?? "", /enc:encoded-route$/);
  assert.equal(url.searchParams.getAll("markers").length, 2);
  assert.ok(url.searchParams.getAll("style").length >= 6);
});

test("extends the map north without changing the original route scale", () => {
  const value = googleStaticMapUrl({
    apiKey: "server-secret",
    encodedPolyline: "",
    origin: {latitude: 34, longitude: -120},
    destination: {latitude: 36, longitude: -122},
  });
  const url = new URL(value);
  const centerParts = (url.searchParams.get("center") ?? "").split(",");
  const latitude = Number(centerParts[0]);
  const longitude = Number(centerParts[1]);

  assert.ok(latitude > 35);
  assert.equal(longitude, -121);
  assert.equal(url.searchParams.get("size"), "640x352");
});

test("builds a credential-free stop picker preview with selected and gas pins", () => {
  const value = rideStopMapPreviewUrl({
    rideId: "ride-1",
    encodedPolyline: "encoded-route",
    selectedStop: {latitude: 34.4123456, longitude: -119.8123456},
    gasStations: [
      {latitude: 34.4, longitude: -119.8},
      {latitude: 34.5, longitude: -119.9},
    ],
  });
  const url = new URL(value);

  assert.equal(url.origin, "https://sidecar-fb0e7.web.app");
  assert.equal(url.searchParams.get("pin"), "34.412346,-119.812346");
  assert.equal(
    url.searchParams.get("gas"),
    "34.400000,-119.800000;34.500000,-119.900000",
  );
  assert.equal(value.includes("key="), false);
});

test("renders selected and gas station markers after the route endpoints", () => {
  const value = googleStaticMapUrl({
    apiKey: "server-secret",
    encodedPolyline: "encoded-route",
    origin: {latitude: 34.4, longitude: -119.8},
    destination: {latitude: 37.6, longitude: -122.4},
    selectedStop: {latitude: 35.1, longitude: -120.2},
    gasStations: [
      {latitude: 34.8, longitude: -120.1},
      {latitude: 35.4, longitude: -120.6},
    ],
  });
  const markers = new URL(value).searchParams.getAll("markers");

  assert.equal(markers.length, 4);
  assert.match(markers[2] ?? "", /34\.8,-120\.1\|35\.4,-120\.6$/);
  assert.match(markers[3] ?? "", /35\.1,-120\.2$/);
});
