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

    expect(booking.status, BookingStatus.confirmed);
    expect(booking.totalLabel, r'$55.92');
    expect(booking.pickupCode, '0909');
    expect(booking.riderPhotoUrl, 'https://example.com/maya.jpg');
    expect(booking.seat, BookingSeat.rearLeft);
    expect(
      booking.pickupLocation?.formattedAddress,
      '6551 Trigo Rd, Isla Vista, CA 93117',
    );
    expect(booking.dropoffLocation?.placeId, 'dropoff-1');
    expect(booking.hasFinancialActivity, isTrue);
  });

  test('seat request sends the selected seat and exact address place IDs', () {
    const request = SeatRequest(
      rideId: 'ride-1',
      seat: BookingSeat.rearRight,
      pickupPlaceId: 'pickup-1',
      dropoffPlaceId: 'dropoff-1',
    );

    expect(request.toJson(), {
      'rideId': 'ride-1',
      'seatKey': 'rear_right',
      'pickupPlaceId': 'pickup-1',
      'dropoffPlaceId': 'dropoff-1',
    });
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

  test('booking timestamps use the same local timezone as ride timestamps', () {
    final booking = SeatBooking.fromJson({
      'id': 'booking-timezone',
      'rideId': 'ride-1',
      'riderId': 'rider-1',
      'riderName': 'Maya Chen',
      'riderInitials': 'MC',
      'riderPhotoUrl': '',
      'driverId': 'driver-1',
      'driverName': 'Jordan T.',
      'status': 'confirmed',
      'originName': 'Isla Vista',
      'destinationName': 'Palo Alto',
      'departureAt': '2026-08-14T19:50:00.000Z',
      'paymentExpiresAt': '2026-08-13T19:50:00.000Z',
    });

    expect(booking.departureAt.isUtc, isFalse);
    expect(
      booking.departureAt.toUtc(),
      DateTime.parse('2026-08-14T19:50:00.000Z'),
    );
    expect(booking.paymentExpiresAt?.isUtc, isFalse);
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
