import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';

abstract interface class BookingRepository {
  Future<SeatBooking> requestSeat(SeatRequest request);
  Future<SeatBooking> respondToRequest(
    String bookingId, {
    required bool accept,
  });
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false});
  Future<List<SeatBooking>> listRideRequests({
    String? rideId,
    bool forceRefresh = false,
  });
  Future<SeatBooking> refreshBooking(String bookingId);
  Future<BookingPaymentQuote> quoteBookingPayment(
    String bookingId,
    BookingPaymentMethod method,
  );
  Future<SeatBooking> payForBooking(
    String bookingId,
    BookingPaymentMethod method,
  );
  Future<List<SavedPaymentMethod>> listPaymentMethods();
  Future<bool> addPaymentMethod([
    BookingPaymentMethod method = BookingPaymentMethod.card,
  ]);
  Future<void> cancelBooking(String bookingId);
  Future<void> cancelDriverRide(String rideId);
  Future<void> verifyPickupCode(String bookingId, String code);
  Future<void> completeTrip(String bookingId);
  Future<void> disputeBooking(String bookingId, String reason);
  Future<Uri> createDriverOnboardingLink();
  Future<DriverPayoutStatus> getDriverPayoutStatus();
}

class UnavailableBookingRepository implements BookingRepository {
  const UnavailableBookingRepository();

  Never _notReady() => throw const AppFailure(
    'Booking services are unavailable in this build.',
    code: 'firebase-not-configured',
  );

  @override
  Future<void> cancelBooking(String bookingId) async => _notReady();
  @override
  Future<bool> addPaymentMethod([
    BookingPaymentMethod method = BookingPaymentMethod.card,
  ]) async => _notReady();
  @override
  Future<void> cancelDriverRide(String rideId) async => _notReady();
  @override
  Future<void> completeTrip(String bookingId) async => _notReady();
  @override
  Future<Uri> createDriverOnboardingLink() async => _notReady();
  @override
  Future<void> disputeBooking(String bookingId, String reason) async =>
      _notReady();
  @override
  Future<DriverPayoutStatus> getDriverPayoutStatus() async => _notReady();
  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) async =>
      _notReady();
  @override
  Future<List<SeatBooking>> listRideRequests({
    String? rideId,
    bool forceRefresh = false,
  }) async => _notReady();
  @override
  Future<List<SavedPaymentMethod>> listPaymentMethods() async => _notReady();
  @override
  Future<SeatBooking> payForBooking(
    String bookingId,
    BookingPaymentMethod method,
  ) async => _notReady();
  @override
  Future<BookingPaymentQuote> quoteBookingPayment(
    String bookingId,
    BookingPaymentMethod method,
  ) async => _notReady();
  @override
  Future<SeatBooking> refreshBooking(String bookingId) async => _notReady();
  @override
  Future<SeatBooking> requestSeat(SeatRequest request) async => _notReady();
  @override
  Future<SeatBooking> respondToRequest(
    String bookingId, {
    required bool accept,
  }) async => _notReady();
  @override
  Future<void> verifyPickupCode(String bookingId, String code) async =>
      _notReady();
}

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => const UnavailableBookingRepository(),
);
