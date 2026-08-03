import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_details_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_home_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_search_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const phase = String.fromEnvironment('M3_E2E_PHASE');
  const email = String.fromEnvironment('M3_E2E_EMAIL');
  const password = String.fromEnvironment('M3_E2E_PASSWORD');
  const visualHoldSeconds = int.fromEnvironment('M3_E2E_VISUAL_HOLD_SECONDS');

  testWidgets('live Milestone 3 $phase flow', (tester) async {
    expect(phase, anyOf('driver', 'rider'));
    expect(email, isNotEmpty);
    expect(password, isNotEmpty);

    final bootstrap = await AppBootstrap.initialize();
    expect(
      bootstrap.firebaseReady,
      isTrue,
      reason:
          'Firebase initialization failed: ${bootstrap.initializationError}',
    );

    await bootstrap.authRepository.signOut();
    final account = await bootstrap.authRepository.signIn(
      email: email,
      password: password,
    );
    expect(account.emailVerified, isTrue);

    final profile = await bootstrap.profileRepository.loadCurrentProfile();
    expect(profile, isNotNull);
    expect(profile!.isComplete, isTrue);
    expect(profile.primaryRole?.name, phase);

    final config = await bootstrap.businessConfigRepository.refresh();
    expect(config.version, 'm3-rides');
    expect(config.irsMileageRate, 0.76);

    final rides = bootstrap.rideRepository;
    final origin = await _firstPlace(rides, 'UC Santa Barbara');
    final destination = await _firstPlace(
      rides,
      'San Francisco International Airport',
    );

    if (phase == 'driver') {
      await expectLater(
        rides.createRide(
          RideDraft(
            origin: origin,
            destination: destination,
            departureAt: DateTime.now().add(const Duration(hours: 25)),
            seats: 3,
            pricePerSeatCents: 100000,
            luggageAllowance: LuggageAllowance.oneSuitcase,
            genderRestriction: RideGenderRestriction.any,
          ),
        ),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.message,
            'message',
            contains('cost-sharing limit'),
          ),
        ),
      );

      final ride = await rides.createRide(
        RideDraft(
          origin: origin,
          destination: destination,
          departureAt: DateTime.now().add(const Duration(hours: 26)),
          seats: 3,
          pricePerSeatCents: 5000,
          luggageAllowance: LuggageAllowance.oneSuitcase,
          genderRestriction: RideGenderRestriction.any,
          repeatWeekly: false,
        ),
      );
      expect(ride.driverName, 'SideCar Driver');
      expect(ride.status, 'published');
      expect(ride.pricePerSeatCents, 5000);
      expect(ride.maximumPriceCents, greaterThanOrEqualTo(5000));
      expect(ride.shareUrl, startsWith('https://sidecar-fb0e7.web.app/ride'));
      expect(ride.encodedPolyline, isNotEmpty);
      await _verifyPublishedRideIsImmutable(ride);

      final recurringRide = await rides.createRide(
        RideDraft(
          origin: origin,
          destination: destination,
          departureAt: DateTime.now().add(const Duration(hours: 50)),
          seats: 3,
          pricePerSeatCents: 5000,
          luggageAllowance: LuggageAllowance.oneSuitcase,
          genderRestriction: RideGenderRestriction.womenOnly,
          repeatWeekly: true,
        ),
      );
      expect(recurringRide.repeatWeekly, isTrue);
      expect(recurringRide.recurrenceId, recurringRide.id);

      final mine = await rides.listMyRides();
      expect(mine.map((item) => item.id), contains(ride.id));
      expect(
        mine
            .where((item) => item.recurrenceId == recurringRide.recurrenceId)
            .length,
        greaterThan(1),
      );
      expect((await rides.getRide(ride.id)).id, ride.id);

      await _mountScreen(
        tester,
        rides,
        const RideHomeScreen(),
        profileRepository: bootstrap.profileRepository,
      );
      expect(find.text('Post your next ride'), findsOneWidget);
      await binding.takeScreenshot('m3-live-driver-home');
      await _holdForVisualQa('driver-home', visualHoldSeconds);

      await _mountScreen(
        tester,
        rides,
        const PostRideScreen(),
        profileRepository: bootstrap.profileRepository,
      );
      expect(find.text('Post a ride'), findsOneWidget);
      await binding.takeScreenshot('m3-live-driver-post');
      await _holdForVisualQa('driver-post', visualHoldSeconds);

      await _mountScreen(
        tester,
        rides,
        const MyRidesScreen(),
        profileRepository: bootstrap.profileRepository,
      );
      expect(find.text('My rides'), findsOneWidget);
      expect(find.text('Recurring'), findsOneWidget);
      expect(find.text(ride.origin.displayName), findsWidgets);
      await binding.takeScreenshot('m3-live-driver-my-rides');
      await _holdForVisualQa('driver-my-rides', visualHoldSeconds);
      return;
    }

    final criteria = RideSearchCriteria(
      originQuery: origin.mainText,
      destinationQuery: destination.mainText,
      pickupPlaceId: origin.placeId,
      dropoffPlaceId: destination.placeId,
      startAt: DateTime.now().subtract(const Duration(hours: 1)),
      endAt: DateTime.now().add(const Duration(hours: 46)),
      luggageRequired: LuggageAllowance.backpack,
    );
    final matches = await rides.searchRides(criteria);
    final ride = matches.firstWhere(
      (item) => item.driverName == 'SideCar Driver',
    );
    expect((await rides.getRide(ride.id)).id, ride.id);
    expect(
      (await rides.listLeavingSoon()).map((item) => item.id),
      contains(ride.id),
    );
    expect(
      (await rides.searchRides(
        criteria.copyWith(driverGender: DriverGenderFilter.men),
      )).map((item) => item.id),
      contains(ride.id),
    );
    expect(
      (await rides.searchRides(
        criteria.copyWith(driverGender: DriverGenderFilter.women),
      )).map((item) => item.id),
      isNot(contains(ride.id)),
    );
    expect(
      (await rides.searchRides(
        criteria.copyWith(luggageRequired: LuggageAllowance.twoPlusBags),
      )).map((item) => item.id),
      isNot(contains(ride.id)),
    );
    expect(
      (await rides.searchRides(
        criteria.copyWith(minimumRating: 5),
      )).map((item) => item.id),
      isNot(contains(ride.id)),
    );
    expect(
      (await rides.searchRides(
        criteria.copyWith(
          originQuery: destination.mainText,
          destinationQuery: origin.mainText,
          pickupPlaceId: destination.placeId,
          dropoffPlaceId: origin.placeId,
        ),
      )).map((item) => item.id),
      isNot(contains(ride.id)),
    );
    final offRoute = await _firstPlace(
      rides,
      'San Diego International Airport',
    );
    expect(
      (await rides.searchRides(
        criteria.copyWith(
          originQuery: offRoute.mainText,
          pickupPlaceId: offRoute.placeId,
        ),
      )).map((item) => item.id),
      isNot(contains(ride.id)),
    );
    await _verifyHostedSharePage(ride);

    await _mountScreen(
      tester,
      rides,
      const RideHomeScreen(),
      profileRepository: bootstrap.profileRepository,
    );
    expect(find.text('Where to?'), findsOneWidget);
    await binding.takeScreenshot('m3-live-rider-home');
    await _holdForVisualQa('rider-home', visualHoldSeconds);

    await _mountScreen(
      tester,
      rides,
      const SearchRidesScreen(),
      profileRepository: bootstrap.profileRepository,
    );
    expect(find.text('Find a ride'), findsOneWidget);
    await binding.takeScreenshot('m3-live-rider-search');
    await _holdForVisualQa('rider-search', visualHoldSeconds);

    await _mountScreen(
      tester,
      rides,
      SearchResultsScreen(criteria: criteria),
      profileRepository: bootstrap.profileRepository,
    );
    expect(find.text('SideCar Driver'), findsWidgets);
    await binding.takeScreenshot('m3-live-rider-results');
    await _holdForVisualQa('rider-results', visualHoldSeconds);

    await _mountScreen(
      tester,
      rides,
      RideDetailsScreen(rideId: ride.id),
      profileRepository: bootstrap.profileRepository,
    );
    expect(find.text('SideCar Driver'), findsOneWidget);
    expect(find.text('Request seat'), findsOneWidget);
    expect(find.byType(RideMapPreview), findsOneWidget);
    await binding.takeScreenshot('m3-live-rider-details');
    await _holdForVisualQa('rider-details', visualHoldSeconds);
  });
}

Future<void> _holdForVisualQa(String screen, int seconds) async {
  if (seconds <= 0) return;
  const targets = String.fromEnvironment('M3_E2E_VISUAL_TARGETS');
  if (targets.isNotEmpty && !targets.split(',').contains(screen)) return;
  debugPrint('Visual QA hold: $screen');
  await Future<void>.delayed(Duration(seconds: seconds));
}

Future<void> _verifyPublishedRideIsImmutable(Ride ride) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  expect(token, isNotNull);
  final client = HttpClient();
  try {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/sidecar-fb0e7/databases/(default)/documents/rides/${ride.id}',
    ).replace(queryParameters: {'updateMask.fieldPaths': 'pricePerSeatCents'});
    final request = await client.patchUrl(uri);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
      ..contentType = ContentType.json;
    request.write(
      jsonEncode({
        'fields': {
          'pricePerSeatCents': {'integerValue': '1'},
        },
      }),
    );
    final response = await request.close();
    await response.drain<void>();
    expect(response.statusCode, HttpStatus.forbidden);
  } finally {
    client.close(force: true);
  }
}

Future<RidePlacePrediction> _firstPlace(
  RideRepository repository,
  String query,
) async {
  final places = await repository.searchPlaces(query);
  expect(places, isNotEmpty, reason: 'No Google Places result for $query.');
  return places.first;
}

Future<void> _verifyHostedSharePage(Ride ride) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(ride.shareUrl));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    expect(response.statusCode, HttpStatus.ok);
    expect(body, contains(ride.origin.displayName));
    expect(body, contains(ride.destination.displayName));
    expect(body, contains('${ride.priceLabel} per seat'));
    expect(body, contains('sidecar://app/rides/${ride.id}'));
  } finally {
    client.close(force: true);
  }
}

Future<void> _mountScreen(
  WidgetTester tester,
  RideRepository repository,
  Widget screen, {
  ProfileRepository? profileRepository,
}) async {
  runApp(
    ProviderScope(
      overrides: [
        rideRepositoryProvider.overrideWithValue(repository),
        if (profileRepository != null)
          profileRepositoryProvider.overrideWithValue(profileRepository),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}
