import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
import 'package:sidecar/src/features/profile/domain/public_profile.dart';
import 'package:sidecar/src/features/profile/domain/public_profile_repository.dart';
import 'package:sidecar/src/features/profile/presentation/public_profile_screen.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
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

SeatBooking _booking() => SeatBooking.fromJson({
  'id': 'booking-1',
  'rideId': 'ride-1',
  'riderId': 'rider-1',
  'riderName': 'Maya Chen',
  'riderInitials': 'MC',
  'riderPhotoUrl': '',
  'driverId': 'driver-1',
  'driverName': 'Jordan',
  'status': 'confirmed',
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
  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) async =>
      const [];

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
