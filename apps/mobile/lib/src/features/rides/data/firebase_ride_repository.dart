import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:sidecar/src/core/data/async_ttl_cache.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';

class FirebaseRideRepository implements RideRepository {
  FirebaseRideRepository(this._functions);

  final FirebaseFunctions _functions;
  static const _timeout = Duration(seconds: 30);
  static const _placeCacheDuration = Duration(minutes: 2);
  static const _rideCacheDuration = Duration(seconds: 20);
  static const _detailsCacheDuration = Duration(minutes: 1);
  final _leavingSoonCache = AsyncTtlCache<List<Ride>>();
  final _myRidesCache = AsyncTtlCache<List<Ride>>();
  final _placeCaches = <String, AsyncTtlCache<List<RidePlacePrediction>>>{};
  final _searchCaches = <String, AsyncTtlCache<List<Ride>>>{};
  final _detailsCaches = <String, AsyncTtlCache<Ride>>{};

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) return const [];
    if (_placeCaches.length >= 40 &&
        !_placeCaches.containsKey(normalizedQuery)) {
      _placeCaches.clear();
    }
    final cache = _placeCaches.putIfAbsent(
      normalizedQuery,
      AsyncTtlCache<List<RidePlacePrediction>>.new,
    );
    return cache.get(_placeCacheDuration, () async {
      final data = await _call('searchPlaces', {'query': query.trim()});
      return _list(data['places'])
          .map((item) => RidePlacePrediction.fromJson(_map(item)))
          .where((place) => place.placeId.isNotEmpty)
          .toList(growable: false);
    });
  }

  @override
  Future<Ride> createRide(RideDraft draft) async {
    final data = await _call('createRide', draft.toJson());
    final ride = Ride.fromJson(_map(data['ride']));
    _myRidesCache.clear();
    _leavingSoonCache.clear();
    _searchCaches.clear();
    return ride;
  }

  @override
  Future<Ride> updateRide(RideUpdate update) async {
    final data = await _call('updateRide', update.toJson());
    final ride = Ride.fromJson(_map(data['ride']));
    _detailsCaches[ride.id]?.clear();
    _myRidesCache.clear();
    _leavingSoonCache.clear();
    _searchCaches.clear();
    return ride;
  }

  @override
  Future<void> cancelRide(String rideId) async {
    await _call('cancelRide', {'rideId': rideId});
    _detailsCaches[rideId]?.clear();
    _myRidesCache.clear();
    _leavingSoonCache.clear();
    _searchCaches.clear();
  }

  @override
  Future<Ride> getRide(String rideId) async {
    final cache = _detailsCaches.putIfAbsent(rideId, AsyncTtlCache<Ride>.new);
    return cache.get(_detailsCacheDuration, () async {
      final data = await _call('getRide', {'rideId': rideId});
      return Ride.fromJson(_map(data['ride']));
    });
  }

  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async {
    return _myRidesCache.get(_rideCacheDuration, () async {
      final data = await _call('listMyRides', const {});
      return _list(
        data['rides'],
      ).map((item) => Ride.fromJson(_map(item))).toList(growable: false);
    }, forceRefresh: forceRefresh);
  }

  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async {
    return _leavingSoonCache.get(_rideCacheDuration, () async {
      final data = await _call('listLeavingSoon', const {});
      return _list(
        data['rides'],
      ).map((item) => Ride.fromJson(_map(item))).toList(growable: false);
    }, forceRefresh: forceRefresh);
  }

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async {
    final key = criteria
        .toJson()
        .entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
    if (_searchCaches.length >= 20 && !_searchCaches.containsKey(key)) {
      _searchCaches.clear();
    }
    final cache = _searchCaches.putIfAbsent(key, AsyncTtlCache<List<Ride>>.new);
    return cache.get(_rideCacheDuration, () async {
      final data = await _call('searchRides', criteria.toJson());
      return _list(
        data['rides'],
      ).map((item) => Ride.fromJson(_map(item))).toList(growable: false);
    });
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, Object?> payload,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(functionName)
          .call<Map<String, dynamic>>(payload)
          .timeout(_timeout);
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw AppFailure(
        error.message ?? 'We could not complete that ride request. Try again.',
        code: error.code,
      );
    } on TimeoutException {
      throw const AppFailure(
        'That took too long. Check your connection and try again.',
        code: 'timeout',
      );
    }
  }
}

class UnavailableRideRepository implements RideRepository {
  const UnavailableRideRepository();

  Never _notReady() => throw const AppFailure(
    'Ride services are unavailable in this build.',
    code: 'firebase-not-configured',
  );

  @override
  Future<Ride> createRide(RideDraft draft) async => _notReady();

  @override
  Future<Ride> updateRide(RideUpdate update) async => _notReady();

  @override
  Future<void> cancelRide(String rideId) async => _notReady();

  @override
  Future<Ride> getRide(String rideId) async => _notReady();

  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async =>
      _notReady();

  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async =>
      _notReady();

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      _notReady();

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async =>
      _notReady();
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const {};
}
