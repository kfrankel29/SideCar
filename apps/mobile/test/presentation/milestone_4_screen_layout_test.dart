import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
import 'package:sidecar/src/features/profile/domain/public_profile.dart';
import 'package:sidecar/src/features/profile/domain/public_profile_repository.dart';
import 'package:sidecar/src/features/profile/presentation/public_profile_screen.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/features/rides/presentation/live_trip_screen.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('checkout matches the Final Draft fee and payment structure', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(_M4Repository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BookingCheckoutScreen(booking: _booking()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Payment method'), findsNothing);
    expect(find.text('Card'), findsNothing);
    expect(find.text('ACH Payment'), findsNothing);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Platform fee'), findsOneWidget);
    expect(find.text('Stripe fee'), findsOneWidget);
    expect(
      find.text('Pickup · 6551 Trigo Rd, Isla Vista, CA 93117'),
      findsOneWidget,
    );
    expect(
      find.text('Drop-off · 95 University Ave, Palo Alto, CA 94301'),
      findsOneWidget,
    );
    expect(find.text(r'Pay $55.92'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pickup code uses the dedicated Final Draft screen', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PickupCodeScreen(booking: _booking()),
      ),
    );

    expect(find.text("You're booked"), findsOneWidget);
    expect(find.text('YOUR PICKUP CODE:'), findsOneWidget);
    for (final digit in ['0', '9', '0', '9']) {
      expect(find.text(digit), findsNWidgets(digit == '0' ? 2 : 2));
    }
    expect(find.text('No code, no charge.'), findsOneWidget);
    expect(find.text('View trip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('payment methods keeps Stripe storage disclosure', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(_M4Repository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PaymentMethodsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment methods'), findsOneWidget);
    expect(find.text('Visa •4417'), findsOneWidget);
    expect(find.text('ACH Payment'), findsNothing);
    expect(find.text('Add payment method'), findsOneWidget);
    expect(find.text('Stored by Stripe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rider can swipe between all My rides tabs', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(_M4Repository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RiderMyRidesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No upcoming rides.'), findsOneWidget);
    await tester.fling(
      find.text('No upcoming rides.'),
      const Offset(-260, 0),
      900,
    );
    await tester.pumpAndSettle();
    expect(find.text('No ride requests.'), findsOneWidget);
    await tester.fling(
      find.text('No ride requests.'),
      const Offset(-260, 0),
      900,
    );
    await tester.pumpAndSettle();
    expect(find.text('No past rides.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requester public profile shows the approved M4 details', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicProfileRepositoryProvider.overrideWithValue(
            _M4PublicProfileRepository(),
          ),
          safetyRepositoryProvider.overrideWithValue(_M4SafetyRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PublicProfileScreen(userId: 'rider-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maya Chen'), findsOneWidget);
    expect(find.text('20 yrs · Female · English'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Report user'), findsOneWidget);
    expect(find.text('Block user'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a blocked profile exposes the unblock action', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicProfileRepositoryProvider.overrideWithValue(
            _M4PublicProfileRepository(),
          ),
          safetyRepositoryProvider.overrideWithValue(
            _M4SafetyRepository(blocked: true),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PublicProfileScreen(userId: 'rider-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unblock user'), findsOneWidget);
    expect(find.text('Block user'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver sees pickups before code entry and selects the rider', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_M4RideRepository()),
          bookingRepositoryProvider.overrideWithValue(
            _M4Repository(bookings: [_booking()]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: LiveTripScreen(
            ride: _liveRide(),
            isDriver: true,
            initialPlan: _livePlan(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pickup order'), findsOneWidget);
    expect(find.text('Honda Civic'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);
    expect(find.text('ETA 3:15 PM'), findsOneWidget);
    expect(find.text('Drop-off order'), findsOneWidget);
    expect(
      find.text(
        'The remaining route will be optimized after every rider is picked up.',
      ),
      findsOneWidget,
    );
    expect(find.text('Enter rider pickup code'), findsOneWidget);

    await tester.tap(find.text('Enter rider pickup code'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm rider pickup'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('Pickup code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rider sees the complete live route and every rider association',
    (tester) async {
      await setPhoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rideRepositoryProvider.overrideWithValue(_M4RideRepository()),
            bookingRepositoryProvider.overrideWithValue(_M4Repository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: LiveTripScreen(
              ride: _liveRide(),
              isDriver: false,
              initialPlan: _livePlan(),
              riderBooking: _booking(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pickup order'), findsOneWidget);
      expect(find.text('Honda Civic'), findsOneWidget);
      expect(find.text('Drop-off order'), findsOneWidget);
      expect(find.text('Maya Chen'), findsNWidgets(2));
      expect(find.text('ETA 3:15 PM'), findsOneWidget);
      expect(find.text('ETA 8:15 PM'), findsOneWidget);
      expect(find.text('View my pickup code'), findsOneWidget);
      expect(find.text('Open directions'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('driver completes a live ride after every rider is picked up', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final bookings = _M4Repository(bookings: [_booking(status: 'in_progress')]);
    final plan = _livePlan(phase: LiveTripPhase.dropoffs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_M4RideRepository(plan)),
          bookingRepositoryProvider.overrideWithValue(bookings),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: LiveTripScreen(
            ride: _liveRide(),
            isDriver: true,
            initialPlan: plan,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ride complete'), findsOneWidget);
    await tester.tap(find.text('Ride complete'));
    await tester.pumpAndSettle();
    expect(find.text('Complete this ride?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Ride complete').last);
    await tester.pumpAndSettle();

    expect(bookings.completedRideId, 'ride-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed live ride moves the rider to trip rating', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final bookings = _M4Repository(bookings: [_booking(status: 'completed')]);
    final plan = _livePlan(phase: LiveTripPhase.complete);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_M4RideRepository(plan)),
          bookingRepositoryProvider.overrideWithValue(bookings),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: LiveTripScreen(
            ride: _liveRide(),
            isDriver: false,
            initialPlan: plan,
            riderBooking: _booking(status: 'completed'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rate driver and trip'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('How was Jordan?-5')));
    await tester.tap(find.byKey(const ValueKey('How was the trip?-4')));
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();

    expect(bookings.ratedBookingId, 'booking-1');
    expect(bookings.driverRating, 5);
    expect(bookings.tripRating, 4);
    expect(tester.takeException(), isNull);
  });
}

class _M4SafetyRepository implements SafetyRepository {
  _M4SafetyRepository({this.blocked = false});

  final bool blocked;

  @override
  Future<bool> isBlocked(String targetUserId) async => blocked;

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

SeatBooking _booking({String status = 'confirmed'}) => SeatBooking.fromJson({
  'id': 'booking-1',
  'rideId': 'ride-1',
  'riderId': 'rider-1',
  'riderName': 'Maya Chen',
  'riderInitials': 'MC',
  'riderPhotoUrl': '',
  'driverId': 'driver-1',
  'driverName': 'Jordan',
  'status': status,
  'originName': 'Pardall Rd',
  'destinationName': 'Palo Alto',
  'departureAt': '2026-08-10T22:00:00.000Z',
  'baseFareCents': 5000,
  'serviceFeeCents': 400,
  'processingFeeCents': 192,
  'totalCents': 5592,
  'pickupCode': '0909',
  'seatKey': 'rear_left',
  'pickupLocation': {
    'placeId': 'pickup-1',
    'displayName': 'Pardall Road',
    'formattedAddress': '6551 Trigo Rd, Isla Vista, CA 93117',
    'latitude': 34.4102,
    'longitude': -119.8554,
  },
  'dropoffLocation': {
    'placeId': 'dropoff-1',
    'displayName': 'Palo Alto Caltrain',
    'formattedAddress': '95 University Ave, Palo Alto, CA 94301',
    'latitude': 37.443,
    'longitude': -122.1652,
  },
});

class _M4Repository extends UnavailableBookingRepository {
  _M4Repository({this.bookings = const []});

  final List<SeatBooking> bookings;
  String? completedRideId;
  String? ratedBookingId;
  int? driverRating;
  int? tripRating;

  @override
  Future<void> completeDriverTrip(String rideId) async {
    completedRideId = rideId;
  }

  @override
  Future<void> rateTrip({
    required String bookingId,
    required int driverRating,
    required int tripRating,
    String comment = '',
  }) async {
    ratedBookingId = bookingId;
    this.driverRating = driverRating;
    this.tripRating = tripRating;
  }

  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) async =>
      bookings;

  @override
  Future<List<SeatBooking>> listRideRequests({
    String? rideId,
    bool forceRefresh = false,
  }) async => bookings;

  @override
  Future<BookingPaymentQuote> quoteBookingPayment(
    String bookingId,
    BookingPaymentMethod method,
  ) async => const BookingPaymentQuote(
    baseFareCents: 5000,
    serviceFeeCents: 400,
    processingFeeCents: 192,
    totalCents: 5592,
  );

  @override
  Future<List<SavedPaymentMethod>> listPaymentMethods() async => const [
    SavedPaymentMethod(
      id: 'pm_card',
      type: BookingPaymentMethod.card,
      label: 'Visa •4417',
      detail: 'Expires 08/28',
    ),
  ];
}

class _M4RideRepository implements RideRepository {
  _M4RideRepository([this.plan]);

  final LiveTripPlan? plan;

  @override
  Future<LiveTripPlan> getLiveTrip(String rideId) async => plan ?? _livePlan();

  @override
  Future<LiveTripPlan> startLiveTrip(String rideId) async => _livePlan();

  Never _unused() => throw UnsupportedError('Unused by this test.');

  @override
  Future<void> cancelRide(String rideId) async => _unused();
  @override
  Future<Ride> createRide(RideDraft draft) async => _unused();
  @override
  Future<Ride> getRide(String rideId) async => _liveRide();
  @override
  void invalidateRide(String rideId) {}
  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async =>
      _unused();
  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async =>
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

Ride _liveRide() => Ride.fromJson({
  'id': 'ride-1',
  'driverId': 'driver-1',
  'driverName': 'Jordan Taylor',
  'driverInitials': 'JT',
  'driverGender': 'Male',
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
    'latitude': 34.41,
    'longitude': -119.85,
  },
  'destination': {
    'placeId': 'destination',
    'displayName': 'Palo Alto',
    'formattedAddress': 'Palo Alto, CA',
    'latitude': 37.44,
    'longitude': -122.16,
  },
  'departureAt': '2026-08-10T22:00:00.000Z',
  'status': 'in_progress',
  'seats': 1,
  'availableSeats': 0,
  'bookedSeats': 1,
  'pricePerSeatCents': 5000,
});

LiveTripPlan _livePlan({LiveTripPhase phase = LiveTripPhase.pickups}) =>
    LiveTripPlan(
      phase: phase,
      startedAt: DateTime(2026, 8, 10, 15),
      updatedAt: DateTime(2026, 8, 10, 15),
      pickupStops: [
        LiveTripStop(
          bookingId: 'booking-1',
          riderId: 'rider-1',
          riderName: 'Maya Chen',
          kind: LiveTripStopKind.pickup,
          order: 0,
          location: const RideLocation(
            placeId: 'pickup-1',
            displayName: 'Pardall Road',
            formattedAddress: '6551 Trigo Rd, Isla Vista, CA 93117',
            latitude: 34.4102,
            longitude: -119.8554,
          ),
          eta: DateTime(2026, 8, 10, 15, 15),
          completedAt: null,
        ),
      ],
      dropoffStops: [
        LiveTripStop(
          bookingId: 'booking-1',
          riderId: 'rider-1',
          riderName: 'Maya Chen',
          kind: LiveTripStopKind.dropoff,
          order: 0,
          location: const RideLocation(
            placeId: 'dropoff-1',
            displayName: 'Palo Alto Caltrain',
            formattedAddress: '95 University Ave, Palo Alto, CA 94301',
            latitude: 37.443,
            longitude: -122.1652,
          ),
          eta: DateTime(2026, 8, 10, 20, 15),
          completedAt: null,
        ),
      ],
      pickupPolyline: 'pickup',
      dropoffPolyline: 'dropoff',
    );

class _M4PublicProfileRepository implements PublicProfileRepository {
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
