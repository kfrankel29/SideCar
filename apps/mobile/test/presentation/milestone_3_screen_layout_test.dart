import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/navigation/presentation/main_tab_shell.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_details_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_home_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_search_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/theme/app_theme.dart';
import 'package:sidecar/src/routing/app_router.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('main tabs use the exported Final Draft Figma assets', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            role: PrimaryRole.rider,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final riderAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toList();
    expect(riderAssets, <String>[
      'assets/icons/tabs/home.png',
      'assets/icons/tabs/search.png',
      'assets/icons/tabs/rides.png',
      'assets/icons/tabs/messages.png',
      'assets/icons/tabs/profile.png',
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            role: PrimaryRole.driver,
            selectedIndex: 1,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final driverAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toList();
    expect(driverAssets[1], 'assets/icons/tabs/post.png');
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search screen contains the Final Draft M3 controls', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SearchRidesScreen()),
    );

    expect(find.text('Find a ride'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Pick Up Location'), findsOneWidget);
    expect(find.text('Drop Off Location'), findsOneWidget);
    expect(find.text('UCSB / Isla Vista'), findsNothing);
    expect(find.text('San Mateo / Peninsula'), findsNothing);
    expect(find.text('Ride with'), findsOneWidget);
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('Male drivers'), findsNothing);
    expect(find.text('Luggage'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('4.8+ rating'), findsOneWidget);
    expect(find.text('SUV'), findsNothing);
    expect(find.text('Search rides'), findsOneWidget);
    expect(
      tester
          .widgetList<RideChoiceChip>(find.byType(RideChoiceChip))
          .where((chip) => chip.selected),
      isEmpty,
    );
    expect(
      find.text(formatShortDate(DateUtils.dateOnly(DateTime.now()))),
      findsOneWidget,
    );
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
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Departure Address'), findsOneWidget);
    expect(find.text('Destination Address'), findsOneWidget);
    expect(find.text('Select time'), findsOneWidget);
    expect(find.text('Price / seat'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    expect(find.text('4+'), findsOneWidget);
    expect(find.text('Luggage per rider'), findsOneWidget);
    expect(find.text('Repeat weekly'), findsNothing);
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('Backpack only'), findsOneWidget);
    expect(find.text('1 suitcase'), findsOneWidget);
    expect(find.text('2+ bags'), findsOneWidget);
    expect(find.text('Post ride · earn ~\$0'), findsNothing);
    expect(find.text('Post ride'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post screen uses keyboard time entry and 4+ seat menu', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const PostRideScreen()),
      ),
    );

    await tester.tap(find.text('4+'));
    await tester.pumpAndSettle();
    expect(find.text('4 seats'), findsOneWidget);
    expect(find.text('5 seats'), findsOneWidget);
    expect(find.text('6 seats'), findsOneWidget);
    await tester.tap(find.text('6 seats'));
    await tester.pumpAndSettle();
    expect(find.text('4+'), findsOneWidget);

    await tester.tap(find.text('Select time'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsAtLeastNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver second tab resolves to post ride, not ride details', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final container = ProviderContainer(
      overrides: [
        rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        profileRepositoryProvider.overrideWithValue(_ProfileRepository()),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();

    expect(find.byType(PostRideScreen), findsOneWidget);
    expect(find.byType(RideDetailsScreen), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.postRide);
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

    await tester.tap(find.text('Pick Up Location'));
    await tester.pumpAndSettle();
    expect(find.text('Pickup area'), findsOneWidget);
    Navigator.of(tester.element(find.text('Pickup area'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drop Off Location'));
    await tester.pumpAndSettle();
    expect(find.text('Drop-off area'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Final Draft filters start empty and can be selected', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SearchRidesScreen()),
    );

    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Luggage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 suitcase').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('4.8+ rating'));
    await tester.pump();

    final selected = tester
        .widgetList<RideChoiceChip>(find.byType(RideChoiceChip))
        .where((chip) => chip.selected)
        .map((chip) => chip.label)
        .toSet();
    expect(
      selected,
      containsAll(<String>{'Luggage', 'Language', '4.8+ rating'}),
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route preview never paints a fabricated route', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: RideMapPreview()),
      ),
    );

    expect(find.byType(RideMapPreview), findsOneWidget);
    expect(find.text('Map unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ride cards render the driver profile photo', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: RideCard(ride: _ride)),
      ),
    );

    final avatar = tester.widget<RideAvatar>(find.byType(RideAvatar));
    expect(avatar.photoUrl, 'https://example.test/driver.jpg');
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route preview shows loading without retaining another map', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RideMapPreview(
            mapPreviewUrl: 'https://example.invalid/route-map.png',
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.useOldImageOnUrlChange, isFalse);
    expect(image.placeholder, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ride map extends under status area while controls stay clear', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _RiderAuthRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 812),
              padding: EdgeInsets.only(top: 59, bottom: 34),
              viewPadding: EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: child!,
          ),
          home: const RideDetailsScreen(rideId: 'layout-ride'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapRect = tester.getRect(find.byType(RideMapPreview));
    final backRect = tester.getRect(find.byTooltip('Back'));
    expect(mapRect.top, 0);
    expect(mapRect.height, closeTo(206.66, 0.1));
    expect(backRect.top, greaterThanOrEqualTo(59));
    expect(backRect.bottom, lessThan(mapRect.bottom));
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

    expect(find.text('Your upcoming rides'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver ride management uses requests and immutable rides', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const MyRidesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Recurring'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'results identify closest rides when the requested day is empty',
    (tester) async {
      await setPhoneSize(tester);
      final selectedDate = DateUtils.dateOnly(DateTime.now());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: SearchResultsScreen(
              criteria: RideSearchCriteria(
                originQuery: 'UCSB',
                destinationQuery: 'SFO',
                pickupPlaceId: 'pickup',
                dropoffPlaceId: 'dropoff',
                startAt: selectedDate,
                endAt: selectedDate.add(const Duration(days: 1)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Closest available'), findsOneWidget);
      expect(find.text('Soonest'), findsNothing);
      expect(find.text('Top rated'), findsNothing);
      expect(find.text('SUV'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a driver manages their own ride instead of requesting a seat', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _RideOwnerAuthRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RideDetailsScreen(rideId: 'layout-ride'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit ride'), findsNothing);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Your ride'), findsOneWidget);
    expect(find.text('Start trip'), findsOneWidget);
    expect(find.text('Price / seat'), findsOneWidget);
    expect(find.text('Luggage per rider'), findsOneWidget);
    expect(find.byType(RideMapPreview), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Request seat'), findsNothing);
    expect(find.text('Pick your seat'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _PlacesOnlyRepository implements RideRepository {
  @override
  void invalidateRide(String rideId) {}

  @override
  Future<void> cancelRide(String rideId) async {}

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      const [];

  @override
  Future<Ride> createRide(RideDraft draft) => throw UnimplementedError();

  @override
  Future<Ride> getRide(String rideId) async => _ride;

  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async => [
    _ride,
  ];

  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async => [_ride];

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async => [_ride];

  @override
  Future<Ride> updateRide(RideUpdate update) => throw UnimplementedError();
}

class _RideOwnerAuthRepository implements AuthRepository {
  const _RideOwnerAuthRepository();

  static const _user = AccountUser(
    id: 'driver',
    email: 'driver@ucsb.edu',
    emailVerified: true,
  );

  @override
  AccountUser? get currentUser => _user;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(_user);

  @override
  Future<AccountUser?> validateCurrentSession() async => _user;

  @override
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> requestPasswordResetCode(String email) =>
      throw UnimplementedError();

  @override
  Future<void> resendEmailVerificationCode() => throw UnimplementedError();

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AccountUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> verifyEmailCode(String code) => throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();
}

class _RiderAuthRepository extends _RideOwnerAuthRepository {
  const _RiderAuthRepository();

  static const _rider = AccountUser(
    id: 'rider',
    email: 'rider@ucsb.edu',
    emailVerified: true,
  );

  @override
  AccountUser? get currentUser => _rider;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(_rider);

  @override
  Future<AccountUser?> validateCurrentSession() async => _rider;
}

final _ride = Ride.fromJson({
  'id': 'layout-ride',
  'driverId': 'driver',
  'driverName': 'SideCar Driver',
  'driverInitials': 'SD',
  'driverPhotoUrl': 'https://example.test/driver.jpg',
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
