import assert from "node:assert/strict";
import test from "node:test";
import {preferredDriverPhotoUrl} from "./ride_driver_profile.js";

test("uses the current profile photo for existing and new rides", () => {
  assert.equal(
    preferredDriverPhotoUrl(" https://cdn.example/current.jpg ", "old.jpg"),
    "https://cdn.example/current.jpg",
  );
});

test("falls back to the ride snapshot only when the current profile has no photo", () => {
  assert.equal(preferredDriverPhotoUrl("", " stored.jpg "), "stored.jpg");
  assert.equal(preferredDriverPhotoUrl(undefined, undefined), "");
});
