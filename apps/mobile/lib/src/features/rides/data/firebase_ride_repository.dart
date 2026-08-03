import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';

class FirebaseRideRepository implements RideRepository {
  FirebaseRideRepository(this._functions);

  final FirebaseFunctions _functions;
  static const _timeout = Duration(seconds: 30);

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async {
    if (query.trim().length < 2) return const [];
    final data = await _call('searchPlaces', {'query': query.trim()});
    return _list(data['places'])
        .map((item) => RidePlacePrediction.fromJson(_map(item)))
        .where((place) => place.placeId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Ride> createRide(RideDraft draft) async {
    final data = await _call('createRide', draft.toJson());
    return Ride.fromJson(_map(data['ride']));
  }

  @override
  Future<Ride> getRide(String rideId) async {
    final data = await _call('getRide', {'rideId': rideId});
    return Ride.fromJson(_map(data['ride']));
  }

  @override
  Future<List<Ride>> listMyRides() async {
    final data = await _call('listMyRides', const {});
    return _list(
      data['rides'],
    ).map((item) => Ride.fromJson(_map(item))).toList(growable: false);
  }

  @override
  Future<List<Ride>> listLeavingSoon() async {
    final data = await _call('listLeavingSoon', const {});
    return _list(
      data['rides'],
    ).map((item) => Ride.fromJson(_map(item))).toList(growable: false);
  }

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async {
    final data = await _call('searchRides', criteria.toJson());
    return _list(
      data['rides'],
    ).map((item) => Ride.fromJson(_map(item))).toList(growable: false);
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
  Future<Ride> getRide(String rideId) async => _notReady();

  @override
  Future<List<Ride>> listMyRides() async => _notReady();

  @override
  Future<List<Ride>> listLeavingSoon() async => _notReady();

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
