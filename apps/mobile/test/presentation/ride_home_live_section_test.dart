import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/data/firebase_ride_repository.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/ride_home_screen.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  testWidgets('driver home shows the active trip above upcoming rides', (
    tester,
  ) async {
    await _pumpHome(tester, role: PrimaryRole.driver);

    expect(find.text('Live Ride'), findsOneWidget);
    expect(
      find.text('Trip in progress · View route and riders'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Live Ride')).dy,
      lessThan(tester.getTopLeft(find.text('Your upcoming rides')).dy),
    );
  });

  testWidgets('rider home shows the active trip above leaving soon', (
    tester,
  ) async {
    await _pumpHome(tester, role: PrimaryRole.rider);

    expect(find.text('Live Ride'), findsOneWidget);
    expect(
      find.text('Trip in progress · View live ride details'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Live Ride')).dy,
      lessThan(tester.getTopLeft(find.text('Leaving soon')).dy),
    );
  });
}

Future<void> _pumpHome(WidgetTester tester, {required PrimaryRole role}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_ProfileRepository(role)),
        rideRepositoryProvider.overrideWithValue(_RideRepository()),
        bookingRepositoryProvider.overrideWithValue(_BookingRepository()),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const RideHomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _RideRepository extends UnavailableRideRepository {
  @override
  Future<Ride> getRide(String rideId) async => _activeRide;

  @override
  Future<LiveTripPlan> getLiveTrip(String rideId) async => _activePlan;

  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async => [];

  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async => [
    _activeRide,
  ];
}

final _activePlan = LiveTripPlan.fromJson({
  'rideId': 'active-ride',
  'phase': 'pickups',
  'pickupPolyline': 'pickup',
  'dropoffPolyline': 'dropoff',
  'pickupStops': const [],
  'dropoffStops': const [],
});

class _BookingRepository extends UnavailableBookingRepository {
  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) async =>
      [_activeBooking];
}

class _ProfileRepository implements ProfileRepository {
  const _ProfileRepository(this.role);

  final PrimaryRole role;

  UserProfile get profile => UserProfile(
    userId: role == PrimaryRole.driver ? 'driver' : 'rider',
    firstName: role == PrimaryRole.driver ? 'Dana' : 'Riley',
    lastName: 'Tester',
    school: 'UCSB',
    photoUrl: '',
    age: 22,
    gender: 'Female',
    language: 'English',
    primaryRole: role,
  );

  @override
  Future<UserProfile?> loadCurrentProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {}

  @override
  Future<void> setPrimaryRole(PrimaryRole role) async {}

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => '';

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);
}

final _activeRide = Ride.fromJson({
  'id': 'active-ride',
  'driverId': 'driver',
  'driverName': 'Dana Tester',
  'driverInitials': 'DT',
  'driverGender': 'Female',
  'driverRating': 4.9,
  'driverTrips': 12,
  'vehicle': {
    'makeAndModel': 'Honda Civic',
    'year': 2024,
    'color': 'Black',
    'photoUrl': '',
  },
  'origin': {
    'placeId': 'origin',
    'displayName': 'Isla Vista',
    'formattedAddress': 'Isla Vista, CA',
    'latitude': 34.413,
    'longitude': -119.861,
  },
  'destination': {
    'placeId': 'destination',
    'displayName': 'Palo Alto',
    'formattedAddress': 'Palo Alto, CA',
    'latitude': 37.442,
    'longitude': -122.143,
  },
  'departureAt': DateTime.now().toIso8601String(),
  'distanceMiles': 300,
  'durationSeconds': 18000,
  'seatsTotal': 3,
  'seatsAvailable': 2,
  'bookedSeats': 1,
  'pricePerSeatCents': 5000,
  'maximumPriceCents': 6000,
  'luggageAllowance': 'backpack',
  'genderRestriction': 'any',
  'status': 'in_progress',
  'shareUrl': '',
});

final _activeBooking = SeatBooking.fromJson({
  'id': 'booking',
  'rideId': 'active-ride',
  'riderId': 'rider',
  'riderName': 'Riley Tester',
  'riderInitials': 'RT',
  'driverId': 'driver',
  'driverName': 'Dana Tester',
  'status': 'in_progress',
  'originName': 'Isla Vista',
  'destinationName': 'Palo Alto',
  'departureAt': DateTime.now().toIso8601String(),
  'baseFareCents': 5000,
  'serviceFeeCents': 400,
  'processingFeeCents': 190,
  'totalCents': 5590,
});
