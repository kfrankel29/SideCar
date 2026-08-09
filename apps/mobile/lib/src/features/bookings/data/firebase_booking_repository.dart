import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sidecar/src/core/data/async_ttl_cache.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';

class FirebaseBookingRepository implements BookingRepository {
  FirebaseBookingRepository(this._functions);

  final FirebaseFunctions _functions;
  static const _timeout = Duration(seconds: 30);
  static const _cacheDuration = Duration(seconds: 10);
  final _riderCache = AsyncTtlCache<List<SeatBooking>>();
  final _driverCache = AsyncTtlCache<List<SeatBooking>>();

  @override
  Future<SeatBooking> requestSeat(String rideId) async {
    final data = await _call('requestSeat', {'rideId': rideId});
    _clear();
    return SeatBooking.fromJson(_map(data['booking']));
  }

  @override
  Future<SeatBooking> respondToRequest(
    String bookingId, {
    required bool accept,
  }) async {
    final data = await _call('respondSeatRequest', {
      'bookingId': bookingId,
      'accept': accept,
    });
    _clear();
    return SeatBooking.fromJson(_map(data['booking']));
  }

  @override
  Future<List<SeatBooking>> listMyBookings({bool forceRefresh = false}) =>
      _riderCache.get(_cacheDuration, () async {
        final data = await _call('listMyBookings', const {});
        return _list(data['bookings'])
            .map((value) => SeatBooking.fromJson(_map(value)))
            .toList(growable: false);
      }, forceRefresh: forceRefresh);

  @override
  Future<List<SeatBooking>> listRideRequests({
    String? rideId,
    bool forceRefresh = false,
  }) => _driverCache.get(_cacheDuration, () async {
    final data = await _call('listRideRequests', {'rideId': ?rideId});
    return _list(
      data['bookings'],
    ).map((value) => SeatBooking.fromJson(_map(value))).toList(growable: false);
  }, forceRefresh: forceRefresh);

  @override
  Future<SeatBooking> refreshBooking(String bookingId) async {
    final data = await _call('refreshBooking', {'bookingId': bookingId});
    return SeatBooking.fromJson(_map(data['booking']));
  }

  @override
  Future<BookingPaymentQuote> quoteBookingPayment(
    String bookingId,
    BookingPaymentMethod method,
  ) async {
    final data = await _call('quoteBookingPayment', {
      'bookingId': bookingId,
      'paymentMethod': method.wireValue,
    });
    return BookingPaymentQuote.fromJson(_map(data['amounts']));
  }

  @override
  Future<SeatBooking> payForBooking(
    String bookingId,
    BookingPaymentMethod method,
  ) async {
    final payment = await _call('createBookingPayment', {
      'bookingId': bookingId,
      'paymentMethod': method.wireValue,
    });
    final clientSecret = payment['clientSecret'] as String? ?? '';
    if (clientSecret.isEmpty) {
      throw const AppFailure('Payment could not be initialized. Try again.');
    }
    await _configureStripe(payment);
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        customerId: payment['customerId'] as String?,
        customerEphemeralKeySecret: payment['ephemeralKeySecret'] as String?,
        merchantDisplayName:
            payment['merchantDisplayName'] as String? ?? 'SideCar',
        style: ThemeMode.light,
        allowsDelayedPaymentMethods:
            payment['allowsDelayedPaymentMethods'] == true,
        paymentMethodOrder: method == BookingPaymentMethod.bank
            ? const ['us_bank_account']
            : const ['card'],
        returnURL: 'sidecar://app/stripe-redirect',
      ),
    );
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) {
        throw const AppFailure('Payment was cancelled.', code: 'cancelled');
      }
      throw AppFailure(error.error.localizedMessage ?? 'Payment failed.');
    }
    _clear();
    for (var attempt = 0; attempt < 8; attempt++) {
      final booking = await refreshBooking(bookingId);
      if (booking.status != BookingStatus.paymentProcessing) return booking;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return refreshBooking(bookingId);
  }

  @override
  Future<List<SavedPaymentMethod>> listPaymentMethods() async {
    final data = await _call('listPaymentMethods', const {});
    return _list(data['methods'])
        .map((value) => SavedPaymentMethod.fromJson(_map(value)))
        .toList(growable: false);
  }

  @override
  Future<void> addPaymentMethod() async {
    final setup = await _call('createPaymentMethodSetup', const {});
    final clientSecret = setup['clientSecret'] as String? ?? '';
    if (clientSecret.isEmpty) {
      throw const AppFailure('Payment setup could not be initialized.');
    }
    await _configureStripe(setup);
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        setupIntentClientSecret: clientSecret,
        customerId: setup['customerId'] as String?,
        customerEphemeralKeySecret: setup['ephemeralKeySecret'] as String?,
        merchantDisplayName:
            setup['merchantDisplayName'] as String? ?? 'SideCar',
        style: ThemeMode.light,
        allowsDelayedPaymentMethods: true,
        paymentMethodOrder: const ['card', 'us_bank_account'],
        returnURL: 'sidecar://app/stripe-redirect',
      ),
    );
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) return;
      throw AppFailure(error.error.localizedMessage ?? 'Payment setup failed.');
    }
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    await _call('cancelSeatBooking', {'bookingId': bookingId});
    _clear();
  }

  @override
  Future<void> cancelDriverRide(String rideId) async {
    await _call('cancelDriverRide', {'rideId': rideId});
    _clear();
  }

  @override
  Future<void> verifyPickupCode(String bookingId, String code) async {
    await _call('verifyPickupCode', {'bookingId': bookingId, 'code': code});
    _clear();
  }

  @override
  Future<void> completeTrip(String bookingId) async {
    await _call('completeTrip', {'bookingId': bookingId});
    _clear();
  }

  @override
  Future<void> disputeBooking(String bookingId, String reason) async {
    await _call('disputeBooking', {'bookingId': bookingId, 'reason': reason});
    _clear();
  }

  @override
  Future<Uri> createDriverOnboardingLink() async {
    final data = await _call('createDriverConnectAccount', const {});
    final uri = Uri.tryParse(data['url'] as String? ?? '');
    if (uri == null || !uri.isScheme('https')) {
      throw const AppFailure('Payout setup could not be opened.');
    }
    return uri;
  }

  @override
  Future<DriverPayoutStatus> getDriverPayoutStatus() async {
    final data = await _call('getDriverPayoutStatus', const {});
    return DriverPayoutStatus.fromJson(data);
  }

  void _clear() {
    _riderCache.clear();
    _driverCache.clear();
  }

  Future<void> _configureStripe(Map<String, dynamic> data) async {
    final publishableKey = data['publishableKey'] as String? ?? '';
    if (publishableKey.isEmpty) {
      throw const AppFailure('Payment configuration is incomplete.');
    }
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, Object?> payload,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(functionName)
          .call<Map<String, dynamic>>(payload)
          .timeout(_timeout);
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw AppFailure(
        error.message ?? 'We could not complete that booking request.',
        code: error.code,
      );
    } on TimeoutException {
      throw const AppFailure(
        'That took too long. Check your connection and try again.',
        code: 'timeout',
      );
    }
  }
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return const {};
}
