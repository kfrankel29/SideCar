import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/features/auth/data/firebase_auth_repository.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/auth/presentation/guest_access.dart';
import 'package:sidecar/src/features/profile/data/firebase_profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/rides/data/firebase_ride_repository.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  testWidgets('guest launch opens Home and protected tabs request auth', (
    tester,
  ) async {
    final container = _guestContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    expect(find.text('Find your ride'), findsOneWidget);
    expect(find.text('UCSB'), findsOneWidget);
    expect(find.text('San Francisco'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();

    expect(find.text('Join SideCar'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Continue browsing'), findsOneWidget);
  });

  testWidgets('guest seat request remembers the ride through login', (
    tester,
  ) async {
    final container = _guestContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);

    await tester.tap(find.text('UCSB').last);
    await tester.pumpAndSettle();
    expect(find.text('Request seat'), findsOneWidget);

    await tester.tap(find.text('Request seat'));
    await tester.pumpAndSettle();
    expect(find.text('Request this seat'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      container.read(pendingAuthDestinationProvider),
      contains('/rides/guest-ride?'),
    );
    expect(
      container.read(pendingAuthDestinationProvider),
      contains('resume=request-seat'),
    );
  });

  testWidgets(
    'guest protected deep link opens login and remembers destination',
    (tester) async {
      final container = _guestContainer();
      addTearDown(container.dispose);
      await _pumpApp(tester, container);

      container.read(appRouterProvider).go('/messages/conversation-1');
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        container.read(pendingAuthDestinationProvider),
        '/messages/conversation-1',
      );
    },
  );
}

ProviderContainer _guestContainer() => ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(const _GuestAuthRepository()),
    profileRepositoryProvider.overrideWithValue(
      const UnavailableProfileRepository(),
    ),
    rideRepositoryProvider.overrideWithValue(_GuestRideRepository()),
    businessConfigRepositoryProvider.overrideWithValue(
      MemoryBusinessConfigRepository(localDisplayConfig()),
    ),
  ],
);

Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle();
}

class _GuestAuthRepository extends UnavailableAuthRepository {
  const _GuestAuthRepository();

  @override
  AccountUser? get currentUser => null;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(null);
}

class _GuestRideRepository extends UnavailableRideRepository {
  _GuestRideRepository()
    : ride = Ride.fromJson({
        'id': 'guest-ride',
        'driverId': 'driver-1',
        'driverName': 'Taylor Driver',
        'driverInitials': 'TD',
        'origin': {
          'placeId': 'ucsb',
          'displayName': 'UCSB',
          'formattedAddress': 'UC Santa Barbara, CA',
          'latitude': 34.414,
          'longitude': -119.848,
        },
        'destination': {
          'placeId': 'sf',
          'displayName': 'San Francisco',
          'formattedAddress': 'San Francisco, CA',
          'latitude': 37.775,
          'longitude': -122.419,
        },
        'departureAt': DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String(),
        'seatsTotal': 3,
        'seatsAvailable': 3,
        'bookedSeats': 0,
        'pricePerSeatCents': 3000,
        'luggageAllowance': 'one_suitcase',
        'genderRestriction': 'any',
        'status': 'published',
      });

  final Ride ride;

  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async => [
    ride,
  ];

  @override
  Future<Ride> getRide(String rideId) async => ride;

  @override
  void invalidateRide(String rideId) {}
}
