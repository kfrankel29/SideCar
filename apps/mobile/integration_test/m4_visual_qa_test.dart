import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final repository = _M4VisualRepository();

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
    };

    for (final entry in screens.entries) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
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
    }
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
    await tester.tap(find.text('ACH Payment'));
    await tester.pumpAndSettle();
    expect(interactionRepository.lastQuotedMethod, BookingPaymentMethod.bank);
    expect(find.text(r'Pay $54.40'), findsOneWidget);
    await tester.tap(find.text(r'Pay $54.40'));
    await tester.pumpAndSettle();
    expect(interactionRepository.lastPaidBookingId, 'booking-m4');
    expect(interactionRepository.lastPaidMethod, BookingPaymentMethod.bank);

    await show(const PaymentMethodsScreen());
    await tester.tap(find.text('Add payment method'));
    await tester.pumpAndSettle();
    expect(interactionRepository.addPaymentMethodCalls, 1);
    expect(interactionRepository.listPaymentMethodCalls, 2);

    await show(const PaymentHistoryScreen());
    expect(find.textContaining('Ride with Jordan'), findsOneWidget);
    expect(interactionRepository.forcedBookingRefreshes, 1);

    await show(const PayoutMethodsScreen());
    expect(find.text('Manage with Stripe'), findsOneWidget);
    await tester.tap(find.text('Manage with Stripe'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await show(const PayoutHistoryScreen());
    expect(find.text('PAYOUT BALANCE'), findsOneWidget);
    expect(find.text(r'$450.00'), findsOneWidget);

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
    final bytes = await binding.takeScreenshot('m4-cancelled-ride-count');
    final file = File(
      '${Directory.systemTemp.path}/m4-cancelled-ride-count.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('QA_SCREENSHOT=${file.path}');
  });
}

SeatBooking _booking({String status = 'confirmed'}) => SeatBooking.fromJson({
  'id': 'booking-m4',
  'rideId': 'ride-m4',
  'riderId': 'rider-m4',
  'riderName': 'Maya Chen',
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
  'payoutStatus': 'paid',
  'driverPayoutCents': 5000,
  'pickupCode': '0909',
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

class _M4InteractionRepository extends _M4VisualRepository {
  BookingPaymentMethod? lastQuotedMethod;
  BookingPaymentMethod? lastPaidMethod;
  String? lastPaidBookingId;
  int addPaymentMethodCalls = 0;
  int listPaymentMethodCalls = 0;
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
  Future<void> addPaymentMethod() async {
    addPaymentMethodCalls += 1;
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
  Future<Ride> getRide(String rideId) async => _unused();
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
