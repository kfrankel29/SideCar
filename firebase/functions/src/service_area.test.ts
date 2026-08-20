import test from "node:test";
import assert from "node:assert/strict";

import {administrativeAreaCode, isCaliforniaAddress} from "./service_area.js";

test("recognizes California from Google address components", () => {
  const components = [
    {longText: "Santa Barbara County", shortText: "Santa Barbara County", types: ["administrative_area_level_2"]},
    {longText: "California", shortText: "CA", types: ["administrative_area_level_1", "political"]},
    {longText: "United States", shortText: "US", types: ["country", "political"]},
  ];
  assert.equal(administrativeAreaCode(components), "CA");
  assert.equal(isCaliforniaAddress(components), true);
});

test("rejects missing and out-of-state address components", () => {
  assert.equal(isCaliforniaAddress(undefined), false);
  assert.equal(isCaliforniaAddress([]), false);
  assert.equal(isCaliforniaAddress([
    {longText: "Nevada", shortText: "NV", types: ["administrative_area_level_1"]},
  ]), false);
});

test("accepts the full California name when a short code is unavailable", () => {
  assert.equal(isCaliforniaAddress([
    {longText: "California", types: ["administrative_area_level_1"]},
  ]), true);
});

test("recognizes legacy Geocoding API address components", () => {
  assert.equal(isCaliforniaAddress([
    {
      long_name: "California",
      short_name: "CA",
      types: ["administrative_area_level_1", "political"],
    },
  ]), true);
});
