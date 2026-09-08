import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const firstEmail = String.fromEnvironment('M5_E2E_FIRST_EMAIL');
  const firstPassword = String.fromEnvironment('M5_E2E_FIRST_PASSWORD');
  const secondEmail = String.fromEnvironment('M5_E2E_SECOND_EMAIL');
  const secondPassword = String.fromEnvironment('M5_E2E_SECOND_PASSWORD');
  const qaRouteId = String.fromEnvironment('QA_ROUTE_ID');

  testWidgets('validates deployed map feedback without creating client data', (
    tester,
  ) async {
    expect(firstEmail, isNotEmpty);
    expect(firstPassword, isNotEmpty);
    expect(secondEmail, isNotEmpty);
    expect(secondPassword, isNotEmpty);

    debugPrint('M5_FEEDBACK_STEP=bootstrap');
    final bootstrap = await AppBootstrap.initialize().timeout(
      const Duration(seconds: 40),
    );
    expect(bootstrap.firebaseReady, isTrue);

    debugPrint('M5_FEEDBACK_STEP=first-account');
    final first = await _account(
      bootstrap,
      email: firstEmail,
      password: firstPassword,
    );
    debugPrint('M5_FEEDBACK_STEP=second-account');
    final second = await _account(
      bootstrap,
      email: secondEmail,
      password: secondPassword,
    );
    final driver = first.role == PrimaryRole.driver ? first : second;
    final rider = first.role == PrimaryRole.rider ? first : second;
    expect(driver.id, isNot(rider.id));
    debugPrint('M5_FEEDBACK_STEP=driver-sign-in');
    await _signIn(bootstrap, driver);

    debugPrint('M5_FEEDBACK_STEP=origin');
    final origin = await _firstPlace(
      bootstrap,
      '6687 Trigo Road, Goleta, California',
    );
    debugPrint('M5_FEEDBACK_STEP=destination');
    final destination = await _firstPlace(
      bootstrap,
      'San Francisco International Airport',
    );
    Ride? routeRide;
    var createdRouteForTest = false;
    try {
      if (qaRouteId.isNotEmpty) {
        debugPrint('M5_FEEDBACK_STEP=load-route');
        routeRide = await bootstrap.rideRepository
            .getRide(qaRouteId)
            .timeout(const Duration(seconds: 40));
      } else {
        debugPrint('M5_FEEDBACK_STEP=create-route');
        routeRide = await bootstrap.rideRepository
            .createRide(
              RideDraft(
                origin: origin,
                destination: destination,
                departureAt: DateTime.now().add(const Duration(days: 120)),
                seats: 1,
                pricePerSeatCents: 2500,
                luggageAllowance: LuggageAllowance.backpack,
                genderRestriction: RideGenderRestriction.any,
              ),
            )
            .timeout(const Duration(seconds: 40));
        createdRouteForTest = true;
      }
      expect(routeRide.encodedPolyline, isNotEmpty);

      debugPrint('M5_FEEDBACK_STEP=rider-sign-in');
      await _signIn(bootstrap, rider);
      debugPrint('M5_FEEDBACK_STEP=san-jose');
      final sanJose = await _firstPlace(bootstrap, 'San Jose, California');
      debugPrint('M5_FEEDBACK_STEP=corridor-destination');
      final corridorDestination = await _firstPlace(
        bootstrap,
        'San Francisco International Airport',
      );
      final corridorCriteria = RideSearchCriteria(
        originQuery: sanJose.mainText,
        destinationQuery: corridorDestination.mainText,
        pickupPlaceId: sanJose.placeId,
        dropoffPlaceId: corridorDestination.placeId,
        startAt: routeRide.departureAt.subtract(const Duration(hours: 1)),
        endAt: routeRide.departureAt.add(const Duration(hours: 1)),
      );
      expect(
        (await bootstrap.rideRepository
                .searchRides(corridorCriteria)
                .timeout(const Duration(seconds: 40)))
            .map((ride) => ride.id),
        contains(routeRide.id),
        reason:
            'A northbound Goleta-to-San Francisco ride must be discoverable from San Jose.',
      );
      expect(
        (await bootstrap.rideRepository
                .searchRides(
                  corridorCriteria.copyWith(
                    originQuery: corridorDestination.mainText,
                    destinationQuery: sanJose.mainText,
                    pickupPlaceId: corridorDestination.placeId,
                    dropoffPlaceId: sanJose.placeId,
                  ),
                )
                .timeout(const Duration(seconds: 40)))
            .map((ride) => ride.id),
        isNot(contains(routeRide.id)),
        reason: 'The same route must not match an opposite-direction search.',
      );

      debugPrint('M5_FEEDBACK_STEP=driver-resign-in');
      await _signIn(bootstrap, driver);

      RidePlacePrediction? markerToResolve;
      for (final query in ['San Jose', 'San Mateo']) {
        debugPrint('M5_FEEDBACK_STEP=route-context-$query');
        final anchors = await bootstrap.rideRepository
            .searchPlaces(query)
            .timeout(const Duration(seconds: 40));
        expect(anchors, isNotEmpty);
        final context = await bootstrap.rideRepository
            .getRideStopPickerContext(
              routeRide.id,
              searchPlaceIds: anchors
                  .map((place) => place.placeId)
                  .toList(growable: false),
              includeGasStations: true,
              gasStationQuery: query,
            )
            .timeout(const Duration(seconds: 30));
        expect(context.routePoints, isNotEmpty);
        expect(context.searchResults, isNotEmpty);
        expect(context.gasStations, isNotEmpty);
        markerToResolve ??= context.gasStations.first;
        for (final station in context.gasStations) {
          expect(
            _routeDistanceMiles(station, context.routePoints),
            lessThanOrEqualTo(0.5),
            reason:
                '${station.displayName} must remain inside the half-mile route limit',
          );
          expect(
            context.searchResults.any(
              (anchor) => _distanceMiles(station, anchor) <= 15.6,
            ),
            isTrue,
            reason: '${station.displayName} must stay near $query',
          );
        }
      }

      expect(markerToResolve, isNotNull);
      debugPrint('M5_FEEDBACK_STEP=resolve-pin');
      final resolved = await bootstrap.rideRepository
          .resolveRideStopPin(
            routeRide.id,
            latitude: markerToResolve!.latitude,
            longitude: markerToResolve.longitude,
          )
          .timeout(const Duration(seconds: 40));
      expect(resolved.placeId, isNotEmpty);
      expect(resolved.displayName, isNotEmpty);
      expect(resolved.displayName.toLowerCase(), contains('ca'));
    } finally {
      debugPrint('M5_FEEDBACK_STEP=restore');
      if (createdRouteForTest && routeRide != null) {
        await bootstrap.rideRepository
            .cancelRide(routeRide.id)
            .timeout(const Duration(seconds: 40));
      }
      await bootstrap.authRepository.signOut().timeout(
        const Duration(seconds: 20),
      );
    }
  });
}

Future<RidePlacePrediction> _firstPlace(
  AppBootstrapResult bootstrap,
  String query,
) async {
  final matches = await bootstrap.rideRepository
      .searchPlaces(query)
      .timeout(const Duration(seconds: 40));
  expect(matches, isNotEmpty);
  return matches.first;
}

double _routeDistanceMiles(
  RidePlacePrediction station,
  List<RideCoordinate> route,
) {
  expect(route.length, greaterThanOrEqualTo(2));
  const milesPerLatitudeDegree = 69.0;
  final longitudeScale =
      milesPerLatitudeDegree * math.cos(station.latitude * math.pi / 180);
  var closest = double.infinity;
  for (var index = 0; index < route.length - 1; index++) {
    final start = route[index];
    final end = route[index + 1];
    final startX = (start.longitude - station.longitude) * longitudeScale;
    final startY = (start.latitude - station.latitude) * milesPerLatitudeDegree;
    final endX = (end.longitude - station.longitude) * longitudeScale;
    final endY = (end.latitude - station.latitude) * milesPerLatitudeDegree;
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final lengthSquared = deltaX * deltaX + deltaY * deltaY;
    final projection = lengthSquared == 0
        ? 0.0
        : (-(startX * deltaX + startY * deltaY) / lengthSquared).clamp(
            0.0,
            1.0,
          );
    final closestX = startX + projection * deltaX;
    final closestY = startY + projection * deltaY;
    closest = math.min(
      closest,
      math.sqrt(closestX * closestX + closestY * closestY),
    );
  }
  return closest;
}

double _distanceMiles(RidePlacePrediction first, RidePlacePrediction second) {
  return _distanceMilesBetween(
    first.latitude,
    first.longitude,
    second.latitude,
    second.longitude,
  );
}

double _distanceMilesBetween(
  double firstLatitudeDegrees,
  double firstLongitudeDegrees,
  double secondLatitudeDegrees,
  double secondLongitudeDegrees,
) {
  const earthRadiusMiles = 3958.7613;
  final firstLatitude = firstLatitudeDegrees * math.pi / 180;
  final secondLatitude = secondLatitudeDegrees * math.pi / 180;
  final latitudeDelta = secondLatitude - firstLatitude;
  final longitudeDelta =
      (secondLongitudeDegrees - firstLongitudeDegrees) * math.pi / 180;
  final haversine =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(firstLatitude) *
          math.cos(secondLatitude) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return 2 * earthRadiusMiles * math.asin(math.min(1, math.sqrt(haversine)));
}

Future<_Account> _account(
  AppBootstrapResult bootstrap, {
  required String email,
  required String password,
}) async {
  await bootstrap.authRepository.signOut().timeout(const Duration(seconds: 20));
  final user = await bootstrap.authRepository
      .signIn(email: email, password: password)
      .timeout(const Duration(seconds: 40));
  final profile = await bootstrap.profileRepository
      .loadCurrentProfile()
      .timeout(const Duration(seconds: 40));
  expect(profile?.primaryRole, isNotNull);
  return _Account(
    id: user.id,
    email: email,
    password: password,
    role: profile!.primaryRole!,
  );
}

Future<void> _signIn(AppBootstrapResult bootstrap, _Account account) async {
  await bootstrap.authRepository.signOut().timeout(const Duration(seconds: 20));
  await bootstrap.authRepository
      .signIn(email: account.email, password: account.password)
      .timeout(const Duration(seconds: 40));
  final user = FirebaseAuth.instance.currentUser;
  expect(user, isNotNull);
  expect(user!.uid, account.id);
  final token = await user
      .getIdToken(true)
      .timeout(const Duration(seconds: 30));
  expect(token, isNotEmpty);
  final authenticatedUser = await FirebaseAuth.instance
      .idTokenChanges()
      .firstWhere((candidate) => candidate?.uid == account.id)
      .timeout(const Duration(seconds: 5));
  expect(authenticatedUser, isNotNull);
}

class _Account {
  const _Account({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
  });

  final String id;
  final String email;
  final String password;
  final PrimaryRole role;
}
