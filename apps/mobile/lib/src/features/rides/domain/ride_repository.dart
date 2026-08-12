import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';

abstract interface class RideRepository {
  Future<List<RidePlacePrediction>> searchPlaces(String query);
  Future<Ride> createRide(RideDraft draft);
  Future<Ride> updateRide(RideUpdate update);
  Future<void> cancelRide(String rideId);
  Future<List<Ride>> searchRides(RideSearchCriteria criteria);
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false});
  Future<Ride> getRide(String rideId);
  Future<List<Ride>> listMyRides({bool forceRefresh = false});
  void invalidateRide(String rideId);
}

final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => throw StateError('RideRepository has not been initialized.'),
);
