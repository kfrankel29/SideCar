import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/core/data/async_ttl_cache.dart';

void main() {
  test('reuses a cached value until its time to live expires', () async {
    var now = DateTime(2026);
    var loads = 0;
    final cache = AsyncTtlCache<int>(now: () => now);
    Future<int> load() async => ++loads;

    expect(await cache.get(const Duration(seconds: 10), load), 1);
    expect(await cache.get(const Duration(seconds: 10), load), 1);

    now = now.add(const Duration(seconds: 11));
    expect(await cache.get(const Duration(seconds: 10), load), 2);
  });

  test('deduplicates concurrent loads', () async {
    final completion = Completer<int>();
    var loads = 0;
    final cache = AsyncTtlCache<int>();
    Future<int> load() {
      loads += 1;
      return completion.future;
    }

    final first = cache.get(const Duration(seconds: 10), load);
    final second = cache.get(const Duration(seconds: 10), load);

    expect(loads, 1);
    completion.complete(42);
    expect(await first, 42);
    expect(await second, 42);
  });

  test('force refresh and clear bypass a cached value', () async {
    var loads = 0;
    final cache = AsyncTtlCache<int>();
    Future<int> load() async => ++loads;

    expect(await cache.get(const Duration(minutes: 1), load), 1);
    expect(
      await cache.get(const Duration(minutes: 1), load, forceRefresh: true),
      2,
    );
    cache.clear();
    expect(await cache.get(const Duration(minutes: 1), load), 3);
  });

  test('force refresh supersedes an older in-flight load', () async {
    final firstCompletion = Completer<int>();
    final secondCompletion = Completer<int>();
    var loads = 0;
    final cache = AsyncTtlCache<int>();

    Future<int> load() {
      loads += 1;
      return loads == 1 ? firstCompletion.future : secondCompletion.future;
    }

    final first = cache.get(const Duration(minutes: 1), load);
    final second = cache.get(
      const Duration(minutes: 1),
      load,
      forceRefresh: true,
    );

    expect(loads, 2);
    secondCompletion.complete(2);
    expect(await second, 2);
    firstCompletion.complete(1);
    expect(await first, 1);
    expect(await cache.get(const Duration(minutes: 1), load), 2);
  });
}
