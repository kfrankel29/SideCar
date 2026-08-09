import assert from "node:assert/strict";
import test from "node:test";
import {AsyncTtlCache} from "./async_ttl_cache.js";

test("reuses cached values until the TTL expires", async () => {
  let now = 1_000;
  let loads = 0;
  const cache = new AsyncTtlCache(100, () => now);
  const load = async () => ++loads;

  assert.equal(await cache.get(load), 1);
  assert.equal(await cache.get(load), 1);
  now += 101;
  assert.equal(await cache.get(load), 2);
});

test("deduplicates concurrent loads", async () => {
  let resolve!: (value: number) => void;
  let loads = 0;
  const cache = new AsyncTtlCache<number>(100);
  const load = () => {
    loads += 1;
    return new Promise<number>((completion) => {
      resolve = completion;
    });
  };

  const first = cache.get(load);
  const second = cache.get(load);
  assert.equal(loads, 1);
  resolve(42);
  assert.equal(await first, 42);
  assert.equal(await second, 42);
});
