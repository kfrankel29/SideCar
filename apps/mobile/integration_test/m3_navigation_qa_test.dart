import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sidecar/src/app.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/public_profile.dart';
import 'package:sidecar/src/features/profile/domain/public_profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const visualHoldSeconds = int.fromEnvironment('M3_VISUAL_HOLD_SECONDS');
  const visualTargetStage = String.fromEnvironment('M3_VISUAL_TARGET_STAGE');

  Future<void> holdVisualStage(String stage) async {
    if (visualHoldSeconds < 1) return;
    if (visualTargetStage.isNotEmpty && stage != visualTargetStage) return;
    debugPrint('M3_VISUAL_STAGE:$stage');
    await Future<void>.delayed(Duration(seconds: visualHoldSeconds));
  }

  Future<List<int>> capture(String name) async {
    if (Platform.isAndroid) {
      debugPrint('M3_VISUAL_CAPTURE_SKIPPED_ANDROID:$name');
      return const <int>[];
    }
    final bytes = await binding.takeScreenshot(name);
    final output = File('${Directory.systemTemp.path}/$name.png');
    await output.writeAsBytes(bytes, flush: true);
    debugPrint('M3_VISUAL_CAPTURE:${output.path}');
    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:8766/$name'),
    );
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    client.close(force: true);
    debugPrint('M3_VISUAL_CAPTURE_HTTP:$name:${response.statusCode}');
    return bytes;
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
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
          publicProfileRepositoryProvider.overrideWithValue(
            const _QaPublicProfileRepository(),
          ),
          verificationRepositoryProvider.overrideWithValue(
            const _QaVerificationRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(const _QaRideRepository()),
          bookingRepositoryProvider.overrideWithValue(_QaBookingRepository()),
        ],
        child: const SideCarApp(),
      ),
    );
    await tester.pump();
    final driverContext = tester.element(find.byType(MaterialApp));
    final driverRouter = ProviderScope.containerOf(
      driverContext,
    ).read(appRouterProvider);
    for (var attempt = 0; attempt < 3; attempt++) {
      driverRouter.go(AppRoutes.home);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.text('Hey, Jordan'));
      if (find.text('Hey, Jordan').evaluate().isNotEmpty) break;
    }

    expect(find.text('Hey, Jordan'), findsOneWidget);
    expect(find.text('Welcome aboard, Maya'), findsNothing);
    expect(find.text('Total reimbursed'), findsOneWidget);
    await capture('m3-driver-home');
    await holdVisualStage('driver-home');

    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Post a ride'), findsOneWidget);

    expect(find.text('Repeat weekly'), findsNothing);
    expect(find.text('4+'), findsOneWidget);
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('Backpack'), findsOneWidget);
    expect(find.text('Departure City'), findsOneWidget);
    expect(find.text('Destination City'), findsOneWidget);
    expect(find.byKey(const ValueKey('ride-nav-0')), findsOneWidget);
    await tester.tap(find.text('3'));
    await tester.tap(find.text('1 suitcase'));
    await tester.enterText(find.byType(TextField), '50');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Post ride'), findsOneWidget);
    final reminderCopy = find.text(
      'Carry active auto insurance during the trip\n'
      'Wait 10 minutes past pickup time before marking a no-show\n'
      'A 5% platform fee is deducted from your total reimbursement.',
    );
    await tester.scrollUntilVisible(
      reminderCopy,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Drivers must:'), findsOneWidget);
    expect(reminderCopy, findsOneWidget);
    await capture('m3-post-ride');
    await holdVisualStage('post-ride');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Hey, Jordan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Drivers must:'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ride-nav-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ride-nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('My rides'), findsWidgets);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await capture('m3-driver-my-rides');
    await holdVisualStage('my-rides');

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Maya C.'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
    await capture('m3-driver-requests');
    await holdVisualStage('driver-requests');

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Seat request accepted.'), findsOneWidget);
    expect(find.text('No ride requests.'), findsOneWidget);

    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();

    final appContext = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(appContext);
    container.read(appRouterProvider).push('/rides/qa-ride');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Edit ride'), findsNothing);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Request seat'), findsNothing);
    expect(find.text('Your ride'), findsOneWidget);
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.text('Luggage per rider'), findsOneWidget);
    expect(find.text('Rider preference'), findsOneWidget);
    expect(find.text('Vehicle'), findsOneWidget);
    expect(find.text('Maya C.'), findsOneWidget);
    expect(find.text('Start trip'), findsOneWidget);
    ScaffoldMessenger.of(
      tester.element(find.text('Your ride')),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await capture('m3-driver-owner-details');
    await holdVisualStage('owner-ride-details');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ride-nav-4')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Use SideCar as'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Total reimbursed'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Your profile is ready'), findsNothing);
    expect(find.text('Change ride preference'), findsNothing);
    final profileScreenshot = await capture('m3-driver-profile');
    if (visualTargetStage == 'profile') {
      final output = File(
        '${Directory.systemTemp.path}/m3-driver-profile-corrected.png',
      );
      await output.writeAsBytes(profileScreenshot, flush: true);
      debugPrint('M3_VISUAL_CAPTURE:${output.path}');
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:8766/profile'),
      );
      request.contentLength = profileScreenshot.length;
      request.add(profileScreenshot);
      final response = await request.close();
      await response.drain<void>();
      client.close(force: true);
      debugPrint('M3_VISUAL_CAPTURE_HTTP:${response.statusCode}');
    }
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
          publicProfileRepositoryProvider.overrideWithValue(
            const _QaPublicProfileRepository(),
          ),
          verificationRepositoryProvider.overrideWithValue(
            const _QaVerificationRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(
            const _QaRideRepository(riderView: true),
          ),
          bookingRepositoryProvider.overrideWithValue(
            _QaBookingRepository(includeRiderBooking: true),
          ),
        ],
        child: const SideCarApp(),
      ),
    );
    await tester.pump();
    final riderContext = tester.element(find.byType(MaterialApp));
    final riderRouter = ProviderScope.containerOf(
      riderContext,
    ).read(appRouterProvider);
    for (var attempt = 0; attempt < 3; attempt++) {
      riderRouter.go(AppRoutes.home);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.text('Hey, Maya'));
      if (find.text('Hey, Maya').evaluate().isNotEmpty) break;
    }

    expect(find.text('Hey, Maya'), findsOneWidget);
    await capture('m3-rider-home');
    await holdVisualStage('rider-home');

    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Find a ride'), findsOneWidget);
    await tester.tap(find.text('Women only'));
    await tester.pumpAndSettle();
    await capture('m3-find-a-ride');
    await holdVisualStage('find-a-ride');

    await tester.tap(find.byKey(const ValueKey('ride-nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('My rides'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Front seat'), findsNothing);
    expect(find.textContaining('Pickup ·'), findsNothing);
    expect(find.text('Paid · pickup code ready'), findsOneWidget);
    final riderOrigin = find.text('Isla Vista');
    final riderDestination = find.text('Palo Alto');
    expect(
      tester.getCenter(riderOrigin).dy,
      closeTo(tester.getCenter(riderDestination).dy, 1),
    );
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'View code')).height,
      closeTo(40, 1),
    );
    await capture('m3-rider-my-rides');
    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();

    final appContext = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(appContext);
    container
        .read(appRouterProvider)
        .push(
          AppRoutes.searchResults,
          extra: RideSearchCriteria(
            originQuery: 'UCSB',
            destinationQuery: 'San Jose',
            pickupPlaceId: 'ucsb',
            dropoffPlaceId: 'san-jose',
            startAt: DateTime(2037, 7, 10),
            endAt: DateTime(2037, 7, 11),
            driverGender: DriverGenderFilter.women,
            luggageRequired: LuggageAllowance.twoPlusBags,
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('Sofia M.'), findsOneWidget);
    expect(find.textContaining('3 rides'), findsOneWidget);
    await capture('m3-search-results');
    await holdVisualStage('search-results');

    container.read(appRouterProvider).push('/rides/qa-ride');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Request seat'), findsOneWidget);
    expect(find.text('Cancel ride'), findsNothing);
    await capture('m3-rider-ride-details');
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
    bool acceptedLegalTerms = false,
    bool confirmedAge18 = false,
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
  Future<AccountUser> signInWithGoogle({
    bool acceptedLegalTerms = false,
    bool confirmedAge18 = false,
  }) => throw UnimplementedError();

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
        firstName: role == PrimaryRole.driver ? 'Jordan' : 'Maya',
        lastName: role == PrimaryRole.driver ? 'Torres' : 'Chen',
        school: 'UC Santa Barbara',
        age: 21,
        gender: 'Female',
        language: 'English',
        major: role == PrimaryRole.driver ? 'Econ' : '',
        graduationYear: role == PrimaryRole.driver ? 2027 : 0,
        rating: role == PrimaryRole.driver ? 4.9 : 0,
        tripCount: role == PrimaryRole.driver ? 12 : 0,
        totalEarningsCents: role == PrimaryRole.driver ? 45000 : 0,
        photoUrl: '',
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
      model: 'CR-V',
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

class _QaPublicProfileRepository implements PublicProfileRepository {
  const _QaPublicProfileRepository();

  @override
  Future<PublicProfile> getProfile(String userId) async => PublicProfile(
    userId: userId,
    displayName: userId == 'rider-maya' ? 'Maya C.' : 'Sofia M.',
    photoUrl: '',
    age: 21,
    gender: 'Female',
    language: 'English',
    rating: 4.9,
    tripCount: 12,
  );
}

class _QaBookingRepository extends UnavailableBookingRepository {
  _QaBookingRepository({this.includeRiderBooking = false});

  final bool includeRiderBooking;
  bool _hasPendingRequest = true;

  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) async =>
      includeRiderBooking ? [_riderBooking] : const [];

  @override
  Future<List<SeatBooking>> listRideRequests({
    String? rideId,
    bool forceRefresh = false,
  }) async => [_confirmedBooking, if (_hasPendingRequest) _pendingBooking];

  @override
  Future<SeatBooking> respondToRequest(
    String bookingId, {
    required bool accept,
  }) async {
    _hasPendingRequest = false;
    return _confirmedBooking;
  }

  @override
  Future<DriverPayoutStatus> getDriverPayoutStatus() async =>
      const DriverPayoutStatus(
        connected: true,
        payoutsEnabled: true,
        detailsSubmitted: true,
        bankName: 'Visa',
        last4: '4417',
      );
}

final _confirmedBooking = SeatBooking(
  id: 'qa-booking',
  rideId: 'qa-ride',
  riderId: 'rider-maya',
  riderName: 'Maya C.',
  riderInitials: 'MC',
  riderPhotoUrl: '',
  driverId: 'driver-qa',
  driverName: 'Maya Chen',
  driverPhotoUrl: '',
  status: BookingStatus.confirmed,
  originName: 'Isla Vista',
  destinationName: 'Palo Alto',
  departureAt: DateTime(2037, 7, 10, 15),
  baseFareCents: 5600,
  serviceFeeCents: 0,
  processingFeeCents: 0,
  totalCents: 5600,
  pickupLocation: BookingStop(
    placeId: 'iv-deli',
    displayName: 'IV Deli Mart',
    formattedAddress: 'IV Deli Mart, 6549 Pardall Rd',
    latitude: 34.4136,
    longitude: -119.8563,
  ),
);

final _pendingBooking = SeatBooking(
  id: 'qa-pending-booking',
  rideId: 'qa-ride',
  riderId: 'rider-maya',
  riderName: 'Maya C.',
  riderInitials: 'MC',
  riderPhotoUrl: '',
  driverId: 'driver-qa',
  driverName: 'Jordan T.',
  driverPhotoUrl: '',
  status: BookingStatus.pendingDriver,
  originName: 'Isla Vista',
  destinationName: 'Palo Alto',
  departureAt: DateTime(2037, 7, 10, 15),
  baseFareCents: 5600,
  serviceFeeCents: 0,
  processingFeeCents: 0,
  totalCents: 5600,
);

final _riderBooking = SeatBooking(
  id: 'qa-rider-booking',
  rideId: 'booked-ride',
  riderId: 'rider-qa',
  riderName: 'Maya C.',
  riderInitials: 'MC',
  riderPhotoUrl: '',
  driverId: 'driver-sofia',
  driverName: 'Sofia M.',
  driverPhotoUrl: '',
  status: BookingStatus.confirmed,
  originName: 'Isla Vista',
  destinationName: 'Palo Alto',
  departureAt: DateTime(2037, 7, 10, 15),
  baseFareCents: 5600,
  serviceFeeCents: 0,
  processingFeeCents: 0,
  totalCents: 5600,
  pickupLocation: BookingStop(
    placeId: 'iv-deli',
    displayName: 'IV Deli Mart',
    formattedAddress: 'IV Deli Mart, 6549 Pardall Rd',
    latitude: 34.4136,
    longitude: -119.8563,
  ),
);

class _QaRideRepository implements RideRepository {
  const _QaRideRepository({this.riderView = false});

  final bool riderView;

  @override
  void invalidateRide(String rideId) {}

  @override
  Future<void> cancelRide(String rideId) async {}

  @override
  Future<Ride> createRide(RideDraft draft) => throw UnimplementedError();

  @override
  Future<Ride> getRide(String rideId) async => _ride;

  @override
  Future<RideStopPickerContext> getRideStopPickerContext(
    String rideId, {
    String selectedPlaceId = '',
    List<String> searchPlaceIds = const [],
    bool includeGasStations = false,
    String gasStationQuery = '',
    double? gasStationLatitude,
    double? gasStationLongitude,
  }) => throw UnimplementedError();

  @override
  Future<RidePlacePrediction> resolveRideStopPin(
    String rideId, {
    required double latitude,
    required double longitude,
  }) => throw UnimplementedError();

  @override
  Future<LiveTripPlan> getLiveTrip(String rideId) => throw UnimplementedError();

  @override
  Future<LiveTripPlan> startLiveTrip(String rideId) =>
      throw UnimplementedError();

  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async => [
    riderView ? _sofiaRide : _ride,
  ];

  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async => [_ride];

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      const [];

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async => [
    _sofiaSearchRide,
    _searchRide(
      id: 'qa-ride-jordan',
      driverName: 'Jordan T.',
      driverInitials: 'JT',
      rating: 4.9,
      departureAt: DateTime(2037, 7, 10, 15),
      vehicle: 'Honda CR-V',
      priceCents: 5600,
      seatsAvailable: 2,
    ),
    _searchRide(
      id: 'qa-ride-dev',
      driverName: 'Dev K.',
      driverInitials: 'DK',
      rating: 4.7,
      departureAt: DateTime(2037, 7, 10, 17, 15),
      vehicle: 'Toyota RAV4',
      priceCents: 5600,
      seatsAvailable: 3,
    ),
  ];

  @override
  Future<Ride> updateRide(RideUpdate update) async => _ride;
}

final _rideJson = <String, dynamic>{
  'id': 'qa-ride',
  'driverId': 'driver-qa',
  'driverName': 'Jordan T.',
  'driverInitials': 'JT',
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
    'displayName': 'Isla Vista',
    'formattedAddress': 'Isla Vista, CA',
    'latitude': 34.414,
    'longitude': -119.849,
  },
  'destination': {
    'displayName': 'Palo Alto',
    'formattedAddress': 'Palo Alto, CA',
    'latitude': 37.775,
    'longitude': -122.419,
  },
  'departureAt': DateTime(2037, 7, 10, 15).toIso8601String(),
  'distanceMiles': 325,
  'durationSeconds': 18000,
  'seatsTotal': 3,
  'seatsAvailable': 1,
  'bookedSeats': 2,
  'pricePerSeatCents': 5600,
  'maximumPriceCents': 8200,
  'luggageAllowance': 'one_suitcase',
  'genderRestriction': 'any',
  'status': 'published',
  'shareUrl': 'https://sidecar-fb0e7.web.app/ride?id=qa-ride',
  'mapPreviewUrl':
      'https://sidecar-fb0e7.web.app/ride-map?id=m3-filter-mock-14&v=4-runtime-qa-3',
  'encodedPolyline': r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
};

final _ride = Ride.fromJson(_rideJson);

final _sofiaRide = Ride.fromJson({
  ..._rideJson,
  'id': 'qa-ride-sofia',
  'driverId': 'driver-sofia',
  'driverName': 'Sofia M.',
  'driverInitials': 'SM',
  'departureAt': DateTime(2037, 7, 10, 13, 30).toIso8601String(),
  'seatsTotal': 2,
  'seatsAvailable': 2,
  'bookedSeats': 0,
  'genderRestriction': 'women_only',
});

final _sofiaSearchRide = Ride.fromJson({
  ..._rideJson,
  'id': 'qa-search-sofia',
  'driverId': 'driver-sofia',
  'driverName': 'Sofia M.',
  'driverInitials': 'SM',
  'driverRating': 5.0,
  'origin': {
    'displayName': 'UCSB',
    'formattedAddress': 'UC Santa Barbara, CA',
    'latitude': 34.414,
    'longitude': -119.849,
  },
  'destination': {
    'displayName': 'San Jose',
    'formattedAddress': 'San Jose, CA',
    'latitude': 37.338,
    'longitude': -121.886,
  },
  'departureAt': DateTime(2037, 7, 10, 13, 30).toIso8601String(),
  'seatsTotal': 2,
  'seatsAvailable': 2,
  'bookedSeats': 0,
  'genderRestriction': 'women_only',
});

Ride _searchRide({
  required String id,
  required String driverName,
  required String driverInitials,
  required double rating,
  required DateTime departureAt,
  required String vehicle,
  required int priceCents,
  required int seatsAvailable,
}) => Ride.fromJson({
  'id': id,
  'driverId': 'driver-$id',
  'driverName': driverName,
  'driverInitials': driverInitials,
  'driverGender': 'Female',
  'driverRating': rating,
  'driverTrips': 18,
  'vehicle': {
    'year': 2023,
    'makeAndModel': vehicle,
    'color': 'Black',
    'photoUrl': '',
  },
  'origin': {
    'displayName': 'UC Santa Barbara',
    'latitude': 34.414,
    'longitude': -119.849,
  },
  'destination': {
    'displayName': 'San Jose',
    'latitude': 37.338,
    'longitude': -121.886,
  },
  'departureAt': departureAt.toIso8601String(),
  'distanceMiles': 285,
  'durationSeconds': 16500,
  'seatsTotal': seatsAvailable,
  'seatsAvailable': seatsAvailable,
  'pricePerSeatCents': priceCents,
  'maximumPriceCents': priceCents + 2500,
  'luggageAllowance': 'one_suitcase',
  'genderRestriction': 'any',
  'status': 'published',
  'shareUrl': 'https://sidecar-fb0e7.web.app/ride?id=$id',
  'mapPreviewUrl': '',
  'encodedPolyline': r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
});
