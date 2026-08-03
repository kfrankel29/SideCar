import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_home_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_search_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('search screen contains the Final Draft M3 controls', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SearchRidesScreen()),
    );

    expect(find.text('Find a ride'), findsOneWidget);
    expect(find.text('UCSB / Isla Vista'), findsOneWidget);
    expect(find.text('San Mateo / Peninsula'), findsOneWidget);
    expect(find.text('Ride with'), findsOneWidget);
    expect(find.text('Women drivers only'), findsOneWidget);
    expect(find.text('Men drivers only'), findsNothing);
    expect(find.text('1 suitcase'), findsOneWidget);
    expect(find.text('4.8+ rating'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('Search rides'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post screen exposes all immutable ride fields', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const PostRideScreen()),
      ),
    );

    expect(find.text('Post a ride'), findsOneWidget);
    expect(find.text('Choose origin'), findsOneWidget);
    expect(find.text('Choose destination'), findsOneWidget);
    expect(find.text('Price / seat'), findsOneWidget);
    expect(find.text('Luggage per rider'), findsOneWidget);
    expect(find.text('Repeat weekly'), findsOneWidget);
    expect(find.text('Women riders only'), findsOneWidget);
    expect(find.text('Men riders only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pickup and drop-off open their own Google Places pickers', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SearchRidesScreen(),
        ),
      ),
    );

    await tester.tap(find.text('UCSB / Isla Vista'));
    await tester.pumpAndSettle();
    expect(find.text('Pickup area'), findsOneWidget);
    Navigator.of(tester.element(find.text('Pickup area'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('San Mateo / Peninsula'));
    await tester.pumpAndSettle();
    expect(find.text('Drop-off area'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route preview accepts a real Google encoded polyline', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: RideMapPreview(encodedPolyline: r'_p~iF~ps|U_ulLnnqC_mqNvxq`@'),
        ),
      ),
    );

    expect(find.byType(RideMapPreview), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver home route card fits a production phone viewport', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
          profileRepositoryProvider.overrideWithValue(_ProfileRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RideHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your upcoming ride'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PlacesOnlyRepository implements RideRepository {
  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      const [];

  @override
  Future<Ride> createRide(RideDraft draft) => throw UnimplementedError();

  @override
  Future<Ride> getRide(String rideId) => throw UnimplementedError();

  @override
  Future<List<Ride>> listLeavingSoon() async => [_ride];

  @override
  Future<List<Ride>> listMyRides() async => [_ride];

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) =>
      throw UnimplementedError();
}

final _ride = Ride.fromJson({
  'id': 'layout-ride',
  'driverId': 'driver',
  'driverName': 'SideCar Driver',
  'driverInitials': 'SD',
  'driverGender': 'Male',
  'driverRating': 4.9,
  'driverTrips': 10,
  'vehicle': {
    'year': 2021,
    'makeAndModel': 'Toyota Prius',
    'color': 'White',
    'photoUrl': '',
  },
  'origin': {
    'displayName': 'University of California, Santa Barbara',
    'latitude': 34.414,
    'longitude': -119.8489,
  },
  'destination': {
    'displayName': 'San Francisco International Airport',
    'latitude': 37.6213,
    'longitude': -122.379,
  },
  'departureAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
  'distanceMiles': 320,
  'durationSeconds': 18000,
  'seatsTotal': 3,
  'seatsAvailable': 3,
  'pricePerSeatCents': 5000,
  'maximumPriceCents': 9000,
  'luggageAllowance': 'one_suitcase',
  'genderRestriction': 'any',
  'status': 'published',
  'shareUrl': 'https://sidecar-fb0e7.web.app/ride/layout-ride',
});

class _ProfileRepository implements ProfileRepository {
  static const profile = UserProfile(
    userId: 'driver',
    firstName: 'SideCar',
    lastName: 'Driver',
    school: 'UCSB',
    photoUrl: 'photo',
    age: 24,
    gender: 'Male',
    language: 'English',
    primaryRole: PrimaryRole.driver,
  );

  @override
  Future<UserProfile?> loadCurrentProfile() async => profile;

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);

  @override
  Future<void> saveProfile(UserProfile profile) => throw UnimplementedError();

  @override
  Future<void> setPrimaryRole(PrimaryRole role) => throw UnimplementedError();

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) => throw UnimplementedError();
}
