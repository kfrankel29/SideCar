import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/features/auth/data/firebase_auth_repository.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
import 'package:sidecar/src/features/profile/domain/public_profile.dart';
import 'package:sidecar/src/features/profile/domain/public_profile_repository.dart';
import 'package:sidecar/src/features/profile/presentation/public_profile_screen.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_details_screen.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final repository = _M4VisualRepository();
  const holdForExternalCapture = bool.fromEnvironment('M4_QA_HOLD');
  const holdSeconds = int.fromEnvironment(
    'M4_QA_HOLD_SECONDS',
    defaultValue: 30,
  );
  const focusedScreen = String.fromEnvironment('M4_QA_SCREEN');

  testWidgets('captures the Milestone 4 Final Draft payment screens', (
    tester,
  ) async {
    final screens = <String, Widget>{
      'm4-checkout': BookingCheckoutScreen(booking: _booking()),
      'm4-pickup-code': PickupCodeScreen(booking: _booking()),
      'm4-payment-methods': const PaymentMethodsScreen(),
      'm4-payment-history': const PaymentHistoryScreen(),
      'm4-payout-methods': const PayoutMethodsScreen(),
      'm4-payout-history': const PayoutHistoryScreen(),
      'm4-rider-my-rides': const RiderMyRidesScreen(),
      'm4-public-profile': const PublicProfileScreen(userId: 'rider-m4'),
    };

    for (final entry in screens.entries) {
      if (focusedScreen.isNotEmpty && entry.key != focusedScreen) {
        continue;
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repository),
            publicProfileRepositoryProvider.overrideWithValue(
              const _M4PublicProfileRepository(),
            ),
            safetyRepositoryProvider.overrideWithValue(_M4SafetyRepository()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: entry.value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final bytes = await binding.takeScreenshot(entry.key);
      final file = File('${Directory.systemTemp.path}/${entry.key}.png');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('QA_SCREENSHOT=${file.path}');
      if (holdForExternalCapture) {
        await Future<void>.delayed(Duration(seconds: holdSeconds));
      }
    }
  });

  testWidgets('captures seat selection and the exact-stop request sheet', (
    tester,
  ) async {
    if (focusedScreen.isNotEmpty && focusedScreen != 'm4-seat-request-stops') {
      return;
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(const _M4AuthRepository()),
          bookingRepositoryProvider.overrideWithValue(
            _EmptyM4BookingRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(
            _M4RideRepository([_publishedRide()]),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const RideDetailsScreen(rideId: 'ride-m4'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Left'));
    await tester.pumpAndSettle();
    expect(find.text('Rear left seat · 3 of 3 left'), findsOneWidget);
    await tester.tap(find.text('Request seat'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your stops'), findsOneWidget);
    expect(find.text('Choose pickup address'), findsOneWidget);
    expect(find.text('Choose drop-off address'), findsOneWidget);
    expect(find.textContaining('within 1 mile'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final bytes = await binding.takeScreenshot('m4-seat-request-stops');
    final file = File('${Directory.systemTemp.path}/m4-seat-request-stops.png');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('QA_SCREENSHOT=${file.path}');
    if (holdForExternalCapture) {
      await Future<void>.delayed(Duration(seconds: holdSeconds));
    }
  });

  testWidgets('paid rider entry points show trip information', (tester) async {
    if (focusedScreen.isNotEmpty &&
        focusedScreen != 'm4-paid-rider-trip-details') {
      return;
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(const _M4AuthRepository()),
          bookingRepositoryProvider.overrideWithValue(repository),
          rideRepositoryProvider.overrideWithValue(
            _M4RideRepository([_publishedRide()]),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const RideDetailsScreen(rideId: 'ride-m4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your trip'), findsOneWidget);
    expect(find.text('View pickup code'), findsOneWidget);
    expect(find.text('Request seat'), findsNothing);
    expect(find.text('Confirm your stops'), findsNothing);
    expect(tester.takeException(), isNull);
    final bytes = await binding.takeScreenshot('m4-paid-rider-trip-details');
    final file = File(
      '${Directory.systemTemp.path}/m4-paid-rider-trip-details.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('QA_SCREENSHOT=${file.path}');
    if (holdForExternalCapture) {
      await Future<void>.delayed(Duration(seconds: holdSeconds));
    }
  });

  testWidgets('driver live trip shows rider-specific stops and pickup choice', (
    tester,
  ) async {
    if (focusedScreen.isNotEmpty && focusedScreen != 'm4-driver-live-trip') {
      return;
    }
    final liveRepository = _M4LiveTripRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _M4DriverAuthRepository(),
          ),
          bookingRepositoryProvider.overrideWithValue(liveRepository),
          rideRepositoryProvider.overrideWithValue(
            _M4RideRepository([_liveRide()]),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const RideDetailsScreen(rideId: 'ride-m4'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip in progress'), findsWidgets);
    expect(find.text('Pickup stops'), findsOneWidget);
    expect(find.text('Drop-off stops'), findsOneWidget);
    expect(find.text('Add rider pickup code'), findsOneWidget);
    expect(find.text('Maya Chen'), findsWidgets);
    expect(find.text('Lena Park'), findsWidgets);
    expect(tester.takeException(), isNull);

    final bytes = await binding.takeScreenshot('m4-driver-live-trip');
    final file = File('${Directory.systemTemp.path}/m4-driver-live-trip.png');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('QA_SCREENSHOT=${file.path}');
    if (holdForExternalCapture) {
      await Future<void>.delayed(Duration(seconds: holdSeconds));
    }

    await tester.tap(find.text('Add rider pickup code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter pickup code'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('Verify and start trip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercises the Milestone 4 payment controls and navigation', (
    tester,
  ) async {
    final interactionRepository = _M4InteractionRepository();
    final rideRepository = _M4RideRepository();

    Future<void> show(Widget screen) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(interactionRepository),
            rideRepositoryProvider.overrideWithValue(rideRepository),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            initialRoute: '/test',
            routes: {
              '/': (_) => const SizedBox.shrink(),
              '/test': (_) => screen,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await show(BookingCheckoutScreen(booking: _booking()));
    expect(find.text(r'Pay $55.92'), findsOneWidget);
    expect(find.text('ACH Payment'), findsNothing);
    expect(interactionRepository.lastQuotedMethod, BookingPaymentMethod.card);
    await tester.tap(find.text(r'Pay $55.92'));
    await tester.pumpAndSettle();
    expect(interactionRepository.lastPaidBookingId, 'booking-m4');
    expect(interactionRepository.lastPaidMethod, BookingPaymentMethod.card);

    await show(const PaymentMethodsScreen());
    expect(find.text('ACH Payment'), findsNothing);
    interactionRepository.paymentMethodAdded = false;
    await tester.tap(find.text('Add payment method'));
    await tester.pumpAndSettle();
    expect(interactionRepository.addPaymentMethodCalls, 1);
    expect(interactionRepository.listPaymentMethodCalls, 1);
    expect(find.text('Payment method added.'), findsNothing);

    interactionRepository.paymentMethodAdded = true;
    await tester.tap(find.text('Add payment method'));
    await tester.pumpAndSettle();
    expect(interactionRepository.addPaymentMethodCalls, 2);
    expect(interactionRepository.lastAddedMethod, BookingPaymentMethod.card);
    expect(interactionRepository.listPaymentMethodCalls, 2);

    await show(const PaymentHistoryScreen());
    expect(find.textContaining('Ride with Jordan'), findsOneWidget);
    expect(interactionRepository.forcedBookingRefreshes, 1);

    await show(const PayoutMethodsScreen());
    expect(find.text('Manage with Stripe'), findsOneWidget);
    await tester.tap(find.text('Manage with Stripe'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    interactionRepository.rideRequests = [
      _booking(),
      _booking(status: 'cancelled', payoutStatus: ''),
    ];
    await show(const PayoutHistoryScreen());
    expect(find.text('PAYOUT BALANCE'), findsOneWidget);
    expect(find.text(r'$450.00'), findsOneWidget);
    expect(
      find.text('Pardall Rd → Palo Alto'),
      findsOneWidget,
      reason: 'Cancelled or refunded bookings are not driver payouts.',
    );

    await show(PickupCodeScreen(booking: _booking()));
    expect(find.text('YOUR PICKUP CODE:'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('9'), findsNWidgets(2));
    await tester.tap(find.text('View trip'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    interactionRepository.myBookings = [_booking(status: 'pending_driver')];
    await show(const RiderMyRidesScreen());
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel request'), findsOneWidget);
    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();
    expect(interactionRepository.cancelledBookingIds, ['booking-m4']);

    interactionRepository.rideRequests = [_booking(status: 'pending_driver')];
    await show(const MyRidesScreen());
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(interactionRepository.responses, ['booking-m4:true']);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(interactionRepository.responses, [
      'booking-m4:true',
      'booking-m4:false',
    ]);
  });

  testWidgets('cancelled driver rides show no active booked seats', (
    tester,
  ) async {
    final rideRepository = _M4RideRepository([_cancelledRide()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(repository),
          rideRepositoryProvider.overrideWithValue(rideRepository),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const MyRidesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();

    expect(find.text('0/3 booked'), findsOneWidget);
    expect(find.text('Cancel ride'), findsNothing);
    expect(find.text('Share link'), findsNothing);
    final bytes = await binding.takeScreenshot('m4-cancelled-ride-count');
    final file = File(
      '${Directory.systemTemp.path}/m4-cancelled-ride-count.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('QA_SCREENSHOT=${file.path}');
  });
}

class _M4SafetyRepository implements SafetyRepository {
  @override
  Future<List<BlockedUser>> listBlockedUsers() async => const [];

  @override
  Future<bool> isBlocked(String targetUserId) async => false;

  @override
  Future<void> blockUser(String targetUserId) async {}

  @override
  Future<void> unblockUser(String targetUserId) async {}

  @override
  Future<void> reportUser({
    required String targetUserId,
    required SafetyReportReason reason,
    String details = '',
  }) async {}
}

SeatBooking _booking({
  String id = 'booking-m4',
  String riderName = 'Maya Chen',
  String status = 'confirmed',
  String payoutStatus = 'paid',
}) => SeatBooking.fromJson({
  'id': id,
  'rideId': 'ride-m4',
  'riderId': 'rider-m4',
  'riderName': riderName,
  'riderInitials': 'MC',
  'riderPhotoUrl': '',
  'driverId': 'driver-m4',
  'driverName': 'Jordan',
  'status': status,
  'originName': 'Pardall Rd',
  'destinationName': 'Palo Alto',
  'departureAt': '2026-08-10T22:00:00.000Z',
  'baseFareCents': 5000,
  'serviceFeeCents': 400,
  'processingFeeCents': 192,
  'totalCents': 5592,
  'paymentStatus': 'paid',
  'payoutStatus': payoutStatus,
  'driverPayoutCents': 5000,
  'pickupCode': '0909',
  'seatKey': 'front',
  'pickupLocation': {
    'placeId': 'pickup-m4',
    'displayName': 'Pardall Road',
    'formattedAddress': 'Pardall Road, Isla Vista, CA 93117',
    'latitude': 34.4138,
    'longitude': -119.8556,
  },
  'dropoffLocation': {
    'placeId': 'dropoff-m4',
    'displayName': 'Palo Alto Caltrain',
    'formattedAddress': '95 University Avenue, Palo Alto, CA 94301',
    'latitude': 37.4434,
    'longitude': -122.1646,
  },
});

Ride _liveRide() => Ride.fromJson({
  'id': 'ride-m4',
  'driverId': 'driver-m4',
  'driverName': 'Jordan Taylor',
  'driverInitials': 'JT',
  'vehicle': {'makeAndModel': 'Honda Civic'},
  'origin': {
    'placeId': 'pickup-m4',
    'displayName': 'Pardall Rd',
    'latitude': 34.4138,
    'longitude': -119.8556,
  },
  'destination': {
    'placeId': 'dropoff-m4',
    'displayName': 'Palo Alto',
    'latitude': 37.4434,
    'longitude': -122.1646,
  },
  'departureAt': '2026-08-12T22:00:00.000Z',
  'seatsTotal': 3,
  'seatsAvailable': 1,
  'bookedSeats': 2,
  'pricePerSeatCents': 5000,
  'luggageAllowance': 'one_suitcase',
  'genderRestriction': 'any',
  'status': 'published',
});

Ride _cancelledRide() => Ride.fromJson({
  'id': 'ride-cancelled',
  'driverId': 'driver-m4',
  'driverName': 'Jordan',
  'driverInitials': 'JT',
  'vehicle': {'makeAndModel': 'Honda Civic'},
  'origin': {'displayName': 'Newport Beach'},
  'destination': {'displayName': 'Palm Beach Gardens'},
  'departureAt': '2026-08-10T22:00:00.000Z',
  'seatsTotal': 3,
  'seatsAvailable': 0,
  'bookedSeats': 3,
  'pricePerSeatCents': 5000,
  'status': 'cancelled',
});

Ride _publishedRide() => Ride.fromJson({
  'id': 'ride-m4',
  'driverId': 'driver-m4',
  'driverName': 'Jordan Taylor',
  'driverInitials': 'JT',
  'driverGender': 'Male',
  'driverRating': 4.9,
  'driverTrips': 12,
  'vehicle': {'makeAndModel': 'Honda Civic'},
  'origin': {
    'placeId': 'pickup-m4',
    'displayName': 'Pardall Rd',
    'latitude': 34.4138,
    'longitude': -119.8556,
  },
  'destination': {
    'placeId': 'dropoff-m4',
    'displayName': 'Palo Alto',
    'latitude': 37.4434,
    'longitude': -122.1646,
  },
  'departureAt': '2026-08-12T22:00:00.000Z',
  'seatsTotal': 3,
  'seatsAvailable': 3,
  'pricePerSeatCents': 5000,
  'luggageAllowance': 'one_suitcase',
  'genderRestriction': 'any',
  'status': 'published',
  'encodedPolyline': r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
});

class _M4AuthRepository extends UnavailableAuthRepository {
  const _M4AuthRepository();

  static const _user = AccountUser(
    id: 'rider-m4',
    email: 'rider@ucsb.edu',
    emailVerified: true,
  );

  @override
  AccountUser get currentUser => _user;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(_user);
}

class _M4DriverAuthRepository extends UnavailableAuthRepository {
  const _M4DriverAuthRepository();

  static const _user = AccountUser(
    id: 'driver-m4',
    email: 'driver@ucsb.edu',
    emailVerified: true,
  );

  @override
  AccountUser get currentUser => _user;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(_user);
}

class _M4PublicProfileRepository implements PublicProfileRepository {
  const _M4PublicProfileRepository();

  @override
  Future<PublicProfile> getProfile(String userId) async => PublicProfile(
    userId: userId,
    displayName: 'Maya Chen',
    photoUrl: '',
    age: 20,
    gender: 'Female',
    language: 'English',
    rating: 4.8,
    tripCount: 6,
  );
}

class _M4VisualRepository extends UnavailableBookingRepository {
  @override
  Future<BookingPaymentQuote> quoteBookingPayment(
    String bookingId,
    BookingPaymentMethod method,
  ) async => BookingPaymentQuote(
    baseFareCents: 5000,
    serviceFeeCents: 400,
    processingFeeCents: method == BookingPaymentMethod.card ? 192 : 40,
    totalCents: method == BookingPaymentMethod.card ? 5592 : 5440,
  );

  @override
  Future<List<SavedPaymentMethod>> listPaymentMethods() async => const [
    SavedPaymentMethod(
      id: 'pm-card',
      type: BookingPaymentMethod.card,
      label: 'Visa •4417',
      detail: 'Expires 08/28 · Maya Chen',
    ),
  ];

  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) async =>
      [_booking()];

  @override
  Future<List<SeatBooking>> listRideRequests({
    String? rideId,
    bool forceRefresh = false,
  }) async => [_booking()];

  @override
  Future<DriverPayoutStatus> getDriverPayoutStatus() async =>
      const DriverPayoutStatus(
        connected: true,
        payoutsEnabled: true,
        detailsSubmitted: true,
        bankName: 'Test Bank',
        last4: '6789',
        availableCents: 45000,
      );
}

class _EmptyM4BookingRepository extends _M4VisualRepository {
  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) async =>
      const [];
}

class _M4LiveTripRepository extends _M4VisualRepository {
  @override
  Future<List<SeatBooking>> listRideRequests({
    String? rideId,
    bool forceRefresh = false,
  }) async => [
    _booking(status: 'in_progress'),
    _booking(id: 'booking-m4-lena', riderName: 'Lena Park'),
  ];
}

class _M4InteractionRepository extends _M4VisualRepository {
  BookingPaymentMethod? lastQuotedMethod;
  BookingPaymentMethod? lastPaidMethod;
  String? lastPaidBookingId;
  int addPaymentMethodCalls = 0;
  BookingPaymentMethod? lastAddedMethod;
  int listPaymentMethodCalls = 0;
  bool paymentMethodAdded = true;
  int forcedBookingRefreshes = 0;
  List<SeatBooking> myBookings = [_booking()];
  List<SeatBooking> rideRequests = [_booking()];
  final List<String> cancelledBookingIds = [];
  final List<String> responses = [];

  @override
  Future<BookingPaymentQuote> quoteBookingPayment(
    String bookingId,
    BookingPaymentMethod method,
  ) {
    lastQuotedMethod = method;
    return super.quoteBookingPayment(bookingId, method);
  }

  @override
  Future<SeatBooking> payForBooking(
    String bookingId,
    BookingPaymentMethod method,
  ) async {
    lastPaidBookingId = bookingId;
    lastPaidMethod = method;
    return _booking();
  }

  @override
  Future<bool> addPaymentMethod([
    BookingPaymentMethod method = BookingPaymentMethod.card,
  ]) async {
    addPaymentMethodCalls += 1;
    lastAddedMethod = method;
    return paymentMethodAdded;
  }

  @override
  Future<List<SavedPaymentMethod>> listPaymentMethods() {
    listPaymentMethodCalls += 1;
    return super.listPaymentMethods();
  }

  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) {
    if (forceRefresh) forcedBookingRefreshes += 1;
    return Future.value(myBookings);
  }

  @override
  Future<List<SeatBooking>> listRideRequests({
    String? rideId,
    bool forceRefresh = false,
  }) async => rideRequests;

  @override
  Future<void> cancelBooking(String bookingId) async {
    cancelledBookingIds.add(bookingId);
  }

  @override
  Future<SeatBooking> respondToRequest(
    String bookingId, {
    required bool accept,
  }) async {
    responses.add('$bookingId:$accept');
    return _booking(status: accept ? 'accepted_payment_pending' : 'declined');
  }
}

class _M4RideRepository implements RideRepository {
  @override
  void invalidateRide(String rideId) {}

  _M4RideRepository([this.rides = const []]);

  final List<Ride> rides;

  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async => rides;

  Never _unused() => throw UnsupportedError('Unused by this QA flow.');

  @override
  Future<void> cancelRide(String rideId) async => _unused();
  @override
  Future<Ride> createRide(RideDraft draft) async => _unused();
  @override
  Future<Ride> getRide(String rideId) async {
    final match = rides.where((ride) => ride.id == rideId);
    if (match.isNotEmpty) return match.first;
    return _publishedRide();
  }

  @override
  Future<RideStopPickerContext> getRideStopPickerContext(
    String rideId, {
    String selectedPlaceId = '',
  }) async => _unused();

  @override
  Future<RidePlacePrediction> resolveRideStopPin(
    String rideId, {
    required double latitude,
    required double longitude,
  }) async => _unused();

  @override
  Future<LiveTripPlan> getLiveTrip(String rideId) async => _unused();
  @override
  Future<LiveTripPlan> startLiveTrip(String rideId) async => _unused();

  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async =>
      _unused();
  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      _unused();
  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async =>
      _unused();
  @override
  Future<Ride> updateRide(RideUpdate update) async => _unused();
}
