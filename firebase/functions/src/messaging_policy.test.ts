import assert from "node:assert/strict";
import test from "node:test";

import {conversationDocumentId, conversationPairKey} from "./messaging_policy.js";

test("conversation identity is stable regardless of participant order", () => {
  assert.equal(conversationPairKey("rider-1", "driver-1"), "driver-1::rider-1");
  assert.equal(conversationPairKey("driver-1", "rider-1"), "driver-1::rider-1");
  assert.equal(conversationDocumentId("rider-1", "driver-1"), "pair_driver-1_rider-1");
  assert.equal(conversationDocumentId("driver-1", "rider-1"), "pair_driver-1_rider-1");
});

test("conversation identity is independent of ride and booking context", () => {
  const firstRidePair = conversationPairKey("rider-1", "driver-1");
  const secondRidePair = conversationPairKey("rider-1", "driver-1");

  assert.equal(firstRidePair, secondRidePair);
  assert.notEqual(firstRidePair, conversationPairKey("rider-2", "driver-1"));
});
