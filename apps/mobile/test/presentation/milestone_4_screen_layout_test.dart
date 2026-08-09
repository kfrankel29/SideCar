import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
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
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('ACH Payment'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Platform fee'), findsOneWidget);
    expect(find.text('Stripe fee'), findsOneWidget);
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
    expect(find.text('ACH Payment'), findsOneWidget);
    expect(find.text('Add payment method'), findsOneWidget);
    expect(find.text('Stored by Stripe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
});

class _M4Repository extends UnavailableBookingRepository {
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
