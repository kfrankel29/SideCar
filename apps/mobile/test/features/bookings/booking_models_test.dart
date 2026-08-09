import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';

void main() {
  test('booking response preserves the paid lifecycle and pickup code', () {
    final booking = SeatBooking.fromJson({
      'id': 'booking-1',
      'rideId': 'ride-1',
      'riderId': 'rider-1',
      'riderName': 'Maya Chen',
      'riderInitials': 'MC',
      'riderPhotoUrl': 'https://example.com/maya.jpg',
      'driverId': 'driver-1',
      'driverName': 'Jordan T.',
      'status': 'confirmed',
      'originName': 'Isla Vista',
      'destinationName': 'Palo Alto Caltrain',
      'departureAt': '2026-08-10T22:00:00.000Z',
      'paymentExpiresAt': '2026-08-09T22:00:00.000Z',
      'baseFareCents': 5000,
      'serviceFeeCents': 400,
      'processingFeeCents': 192,
      'totalCents': 5592,
      'paymentStatus': 'paid',
      'pickupCode': '0909',
    });

    expect(booking.status, BookingStatus.confirmed);
    expect(booking.totalLabel, r'$55.92');
    expect(booking.pickupCode, '0909');
    expect(booking.riderPhotoUrl, 'https://example.com/maya.jpg');
    expect(booking.hasFinancialActivity, isTrue);
  });

  test('pending seat requests are not payment-history entries', () {
    final booking = SeatBooking.fromJson({
      'id': 'booking-pending',
      'rideId': 'ride-1',
      'riderId': 'rider-1',
      'riderName': 'Maya Chen',
      'riderInitials': 'MC',
      'riderPhotoUrl': '',
      'driverId': 'driver-1',
      'driverName': 'Jordan T.',
      'status': 'pending_driver',
      'originName': 'Isla Vista',
      'destinationName': 'Palo Alto',
      'departureAt': '2026-08-12T22:00:00.000Z',
    });

    expect(booking.hasFinancialActivity, isFalse);
    expect(booking.driverPayoutCents, 0);
  });

  test('transactional processing states remain explicit in the client', () {
    expect(
      BookingStatus.fromWire('cancellation_processing'),
      BookingStatus.cancellationProcessing,
    );
    expect(
      BookingStatus.fromWire('completion_processing'),
      BookingStatus.completionProcessing,
    );
  });

  test('driver payout status requires Stripe payouts to be enabled', () {
    final incomplete = DriverPayoutStatus.fromJson({
      'connected': true,
      'detailsSubmitted': true,
      'payoutsEnabled': false,
    });
    final ready = DriverPayoutStatus.fromJson({
      'connected': true,
      'detailsSubmitted': true,
      'payoutsEnabled': true,
    });

    expect(incomplete.payoutsEnabled, isFalse);
    expect(ready.payoutsEnabled, isTrue);
  });

  test('payment quote keeps every displayed amount server-owned', () {
    final quote = BookingPaymentQuote.fromJson({
      'baseFareCents': 5000,
      'serviceFeeCents': 400,
      'processingFeeCents': 192,
      'totalCents': 5592,
    });

    expect(quote.label(quote.baseFareCents), r'$50.00');
    expect(quote.totalLabel, r'$55.92');
  });

  test('saved ACH methods remain distinct from cards', () {
    final method = SavedPaymentMethod.fromJson({
      'id': 'pm_bank',
      'type': 'bank',
      'label': 'Test Bank •6789',
      'detail': 'ACH bank account',
    });

    expect(method.type, BookingPaymentMethod.bank);
    expect(method.label, 'Test Bank •6789');
  });
}
