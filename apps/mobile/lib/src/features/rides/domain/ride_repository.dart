import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';

abstract interface class RideRepository {
  Future<List<RidePlacePrediction>> searchPlaces(String query);
  Future<Ride> createRide(RideDraft draft);
  Future<List<Ride>> searchRides(RideSearchCriteria criteria);
  Future<List<Ride>> listLeavingSoon();
  Future<Ride> getRide(String rideId);
  Future<List<Ride>> listMyRides();
}

final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => throw StateError('RideRepository has not been initialized.'),
);
