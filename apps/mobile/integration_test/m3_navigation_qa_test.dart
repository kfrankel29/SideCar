import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/app.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const visualHoldSeconds = int.fromEnvironment('M3_VISUAL_HOLD_SECONDS');

  Future<void> holdVisualStage(String stage) async {
    if (visualHoldSeconds < 1) return;
    debugPrint('M3_VISUAL_STAGE:$stage');
    await Future<void>.delayed(Duration(seconds: visualHoldSeconds));
  }

  testWidgets('M3 main app uses stateful tabs and owner-aware ride details', (
    tester,
  ) async {
    runApp(
      ProviderScope(
        overrides: [
          businessConfigRepositoryProvider.overrideWithValue(
            MemoryBusinessConfigRepository(localDisplayConfig()),
          ),
          authRepositoryProvider.overrideWithValue(const _QaAuthRepository()),
          profileRepositoryProvider.overrideWithValue(_QaProfileRepository()),
          verificationRepositoryProvider.overrideWithValue(
            const _QaVerificationRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(const _QaRideRepository()),
        ],
        child: const SideCarApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Hey, Maya'), findsOneWidget);
    expect(find.text('Welcome aboard, Maya'), findsNothing);
    await binding.takeScreenshot('m3-driver-home');
    await holdVisualStage('driver-home');

    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Post a ride'), findsOneWidget);

    expect(find.text('Repeat weekly'), findsNothing);
    expect(find.text('4+'), findsOneWidget);
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('Backpack only'), findsOneWidget);
    await binding.takeScreenshot('m3-post-ride');
    await holdVisualStage('post-ride');

    await tester.tap(find.byKey(const ValueKey('ride-nav-0')));
    await tester.pump();
    expect(find.text('Hey, Maya'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pump();
    expect(find.text('Post a ride'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ride-nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('My rides'), findsWidgets);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await binding.takeScreenshot('m3-driver-my-rides');
    await holdVisualStage('my-rides');

    final appContext = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(appContext);
    container.read(appRouterProvider).push('/rides/qa-ride');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Edit ride'), findsNothing);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Request seat'), findsNothing);
    expect(find.text('Your ride'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text('Price / seat'), findsOneWidget);
    expect(find.text('Luggage per rider'), findsOneWidget);
    await binding.takeScreenshot('m3-driver-owner-details');
    await holdVisualStage('owner-ride-details');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ride-nav-4')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Personal information'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Your profile is ready'), findsNothing);
    expect(find.text('Change ride preference'), findsNothing);
    await binding.takeScreenshot('m3-driver-profile');
    await holdVisualStage('profile');
  });

  testWidgets('M3 rider screens match the Final Draft flow', (tester) async {
    runApp(
      ProviderScope(
        overrides: [
          businessConfigRepositoryProvider.overrideWithValue(
            MemoryBusinessConfigRepository(localDisplayConfig()),
          ),
          authRepositoryProvider.overrideWithValue(
            const _QaAuthRepository(
              user: AccountUser(
                id: 'rider-qa',
                email: 'maya@ucsb.edu',
                emailVerified: true,
              ),
            ),
          ),
          profileRepositoryProvider.overrideWithValue(
            _QaProfileRepository(role: PrimaryRole.rider),
          ),
          verificationRepositoryProvider.overrideWithValue(
            const _QaVerificationRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(const _QaRideRepository()),
        ],
        child: const SideCarApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Hey, Maya'), findsOneWidget);
    await binding.takeScreenshot('m3-rider-home');
    await holdVisualStage('rider-home');

    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Find a ride'), findsOneWidget);
    await binding.takeScreenshot('m3-find-a-ride');
    await holdVisualStage('find-a-ride');

    await tester.tap(find.byKey(const ValueKey('ride-nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('My rides'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    await binding.takeScreenshot('m3-rider-my-rides');
    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();

    final appContext = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(appContext);
    container
        .read(appRouterProvider)
        .push(
          AppRoutes.searchResults,
          extra: RideSearchCriteria(
            originQuery: 'UCSB / Isla Vista',
            destinationQuery: 'San Mateo / Peninsula',
            pickupPlaceId: 'ucsb',
            dropoffPlaceId: 'san-mateo',
            startAt: DateUtils.dateOnly(DateTime.now()),
            endAt: DateUtils.dateOnly(
              DateTime.now().add(const Duration(days: 2)),
            ),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('Maya Chen'), findsOneWidget);
    await binding.takeScreenshot('m3-search-results');
    await holdVisualStage('search-results');

    container.read(appRouterProvider).push('/rides/qa-ride');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Request seat'), findsOneWidget);
    expect(find.text('Cancel ride'), findsNothing);
    await binding.takeScreenshot('m3-rider-ride-details');
    await holdVisualStage('rider-ride-details');
  });
}

class _QaAuthRepository implements AuthRepository {
  const _QaAuthRepository({this.user = driver});

  static const driver = AccountUser(
    id: 'driver-qa',
    email: 'maya@ucsb.edu',
    emailVerified: true,
  );

  final AccountUser user;

  @override
  AccountUser? get currentUser => user;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(user);

  @override
  Future<AccountUser?> validateCurrentSession() async => user;

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

class _QaProfileRepository implements ProfileRepository {
  _QaProfileRepository({PrimaryRole role = PrimaryRole.driver})
    : profile = UserProfile(
        userId: role == PrimaryRole.driver ? 'driver-qa' : 'rider-qa',
        firstName: 'Maya',
        lastName: 'Chen',
        school: 'UC Santa Barbara',
        age: 21,
        gender: 'Female',
        language: 'English',
        photoUrl: 'profile-photo',
        primaryRole: role,
      );

  UserProfile profile;

  @override
  Future<UserProfile?> loadCurrentProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> setPrimaryRole(PrimaryRole role) async {
    profile = profile.copyWith(primaryRole: role);
  }

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => 'profile-photo';

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);
}

class _QaVerificationRepository implements VerificationRepository {
  const _QaVerificationRepository();

  static const summary = VerificationSummary(
    identity: VerificationStatus.verified,
    insurance: VerificationStatus.verified,
    vehicle: VehicleProfile(
      year: 2024,
      make: 'Honda',
      model: 'Civic',
      color: 'Black',
      licensePlate: 'SIDECAR',
      photoUrl: 'vehicle-photo',
    ),
  );

  @override
  Future<Uri> createIdentityVerificationSession() => throw UnimplementedError();

  @override
  Future<VerificationSummary> loadCurrentVerification() async => summary;

  @override
  Future<void> saveVehicle(VehicleProfile vehicle) =>
      throw UnimplementedError();

  @override
  Future<void> submitInsuranceDocument({
    required Uint8List bytes,
    required String contentType,
  }) => throw UnimplementedError();

  @override
  Future<String> uploadVehiclePhoto({
    required Uint8List bytes,
    required String contentType,
  }) => throw UnimplementedError();

  @override
  Future<void> verifyInsuranceForTesting() => throw UnimplementedError();

  @override
  Stream<VerificationSummary> watchCurrentVerification() =>
      Stream.value(summary);
}

class _QaRideRepository implements RideRepository {
  @override
  void invalidateRide(String rideId) {}

  const _QaRideRepository();

  @override
  Future<void> cancelRide(String rideId) async {}

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
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      const [];

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async => [_ride];

  @override
  Future<Ride> updateRide(RideUpdate update) async => _ride;
}

final _ride = Ride.fromJson({
  'id': 'qa-ride',
  'driverId': 'driver-qa',
  'driverName': 'Maya Chen',
  'driverInitials': 'MC',
  'driverGender': 'Female',
  'driverRating': 4.9,
  'driverTrips': 12,
  'vehicle': {
    'year': 2024,
    'makeAndModel': 'Honda Civic',
    'color': 'Black',
    'photoUrl': '',
  },
  'origin': {
    'displayName': 'UC Santa Barbara',
    'latitude': 34.414,
    'longitude': -119.849,
  },
  'destination': {
    'displayName': 'San Francisco',
    'latitude': 37.775,
    'longitude': -122.419,
  },
  'departureAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
  'distanceMiles': 325,
  'durationSeconds': 18000,
  'seatsTotal': 3,
  'seatsAvailable': 3,
  'pricePerSeatCents': 5000,
  'maximumPriceCents': 8200,
  'luggageAllowance': 'one_suitcase',
  'genderRestriction': 'any',
  'status': 'published',
  'shareUrl': 'https://sidecar-fb0e7.web.app/ride?id=qa-ride',
  'mapPreviewUrl':
      'https://sidecar-fb0e7.web.app/ride-map?id=m3-filter-mock-14&v=4-runtime-qa-3',
  'encodedPolyline': r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
});
