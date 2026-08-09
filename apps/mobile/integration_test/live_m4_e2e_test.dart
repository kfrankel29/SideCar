import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const phase = String.fromEnvironment('M4_E2E_PHASE');
  const bookingId = String.fromEnvironment('M4_E2E_BOOKING_ID');
  const pickupCode = String.fromEnvironment('M4_E2E_PICKUP_CODE');
  const driverEmail = String.fromEnvironment('M4_E2E_DRIVER_EMAIL');
  const driverPassword = String.fromEnvironment('M4_E2E_DRIVER_PASSWORD');
  const riderEmail = String.fromEnvironment('M4_E2E_RIDER_EMAIL');
  const riderPassword = String.fromEnvironment('M4_E2E_RIDER_PASSWORD');

  testWidgets('live Milestone 4 $phase flow', (tester) async {
    final bootstrap = await AppBootstrap.initialize();
    expect(bootstrap.firebaseReady, isTrue);
    expect(driverEmail, isNotEmpty);
    expect(driverPassword, isNotEmpty);
    expect(riderEmail, isNotEmpty);
    expect(riderPassword, isNotEmpty);

    switch (phase) {
      case 'prepare-payment':
        await _preparePayment(
          bootstrap,
          driverEmail: driverEmail,
          driverPassword: driverPassword,
          riderEmail: riderEmail,
          riderPassword: riderPassword,
        );
        return;
      case 'verify-payment':
        expect(bookingId, isNotEmpty);
        await _verifyPayment(
          bootstrap,
          bookingId,
          riderEmail: riderEmail,
          riderPassword: riderPassword,
        );
        return;
      case 'start-trip':
        expect(bookingId, isNotEmpty);
        expect(pickupCode, matches(RegExp(r'^\d{4}$')));
        await _startTrip(
          bootstrap,
          bookingId,
          pickupCode,
          driverEmail: driverEmail,
          driverPassword: driverPassword,
        );
        return;
      case 'complete-trip':
        expect(bookingId, isNotEmpty);
        await _completeTrip(
          bootstrap,
          bookingId,
          driverEmail: driverEmail,
          driverPassword: driverPassword,
        );
        return;
      case 'prepare-refund':
        await _prepareRefund(
          bootstrap,
          driverEmail: driverEmail,
          driverPassword: driverPassword,
          riderEmail: riderEmail,
          riderPassword: riderPassword,
        );
        return;
      case 'verify-refund':
        expect(bookingId, isNotEmpty);
        await _verifyRefund(
          bootstrap,
          bookingId,
          riderEmail: riderEmail,
          riderPassword: riderPassword,
        );
        return;
      case 'prepare-ach':
        await _prepareAchPayment(
          bootstrap,
          driverEmail: driverEmail,
          driverPassword: driverPassword,
          riderEmail: riderEmail,
          riderPassword: riderPassword,
        );
        return;
      case 'verify-ach':
        expect(bookingId, isNotEmpty);
        await _verifyAchPayment(
          bootstrap,
          bookingId,
          riderEmail: riderEmail,
          riderPassword: riderPassword,
        );
        return;
      default:
        fail('Set M4_E2E_PHASE to a supported live test phase.');
    }
  });
}

Future<void> _preparePayment(
  AppBootstrapResult bootstrap, {
  required String driverEmail,
  required String driverPassword,
  required String riderEmail,
  required String riderPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  final driverProfile = await bootstrap.profileRepository.loadCurrentProfile();
  expect(driverProfile?.isComplete, isTrue);
  expect(driverProfile?.primaryRole, PrimaryRole.driver);
  final payoutStatus = await bootstrap.bookingRepository
      .getDriverPayoutStatus();
  expect(payoutStatus.connected, isTrue);
  expect(payoutStatus.payoutsEnabled, isTrue);

  final origin = await _firstPlace(
    bootstrap,
    'University of California Santa Barbara',
  );
  final destination = await _firstPlace(
    bootstrap,
    'San Francisco International Airport',
  );
  final ride = await bootstrap.rideRepository.createRide(
    RideDraft(
      origin: origin,
      destination: destination,
      departureAt: DateTime.now().add(const Duration(days: 8)),
      seats: 1,
      pricePerSeatCents: 2500,
      luggageAllowance: LuggageAllowance.oneSuitcase,
      genderRestriction: RideGenderRestriction.any,
    ),
  );

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  final request = await bootstrap.bookingRepository.requestSeat(ride.id);
  expect(request.status, BookingStatus.pendingDriver);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  final accepted = await bootstrap.bookingRepository.respondToRequest(
    request.id,
    accept: true,
  );
  expect(accepted.status, BookingStatus.acceptedPaymentPending);
  expect(accepted.paymentExpiresAt, isNotNull);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  final quote = await bootstrap.bookingRepository.quoteBookingPayment(
    request.id,
    BookingPaymentMethod.card,
  );
  expect(quote.baseFareCents, 2500);
  expect(quote.serviceFeeCents, 200);
  expect(quote.processingFeeCents, greaterThan(0));
  expect(quote.totalCents, greaterThan(2700));

  final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('createBookingPayment')
      .call<Map<String, dynamic>>({
        'bookingId': request.id,
        'paymentMethod': 'card',
      });
  final clientSecret = result.data['clientSecret'] as String? ?? '';
  expect(clientSecret, startsWith('pi_'));
  final intentId = clientSecret.split('_secret_').first;
  debugPrint(
    'M4_E2E_RESULT=${jsonEncode({'rideId': ride.id, 'bookingId': request.id, 'paymentIntentId': intentId})}',
  );
}

Future<void> _verifyPayment(
  AppBootstrapResult bootstrap,
  String bookingId, {
  required String riderEmail,
  required String riderPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  SeatBooking booking = await bootstrap.bookingRepository.refreshBooking(
    bookingId,
  );
  for (var attempt = 0; attempt < 12; attempt++) {
    if (booking.status == BookingStatus.confirmed) break;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    booking = await bootstrap.bookingRepository.refreshBooking(bookingId);
  }
  expect(booking.status, BookingStatus.confirmed);
  expect(booking.paymentStatus, 'paid');
  expect(booking.pickupCode, matches(RegExp(r'^\d{4}$')));
  debugPrint(
    'M4_E2E_RESULT=${jsonEncode({'bookingId': booking.id, 'pickupCode': booking.pickupCode, 'totalCents': booking.totalCents})}',
  );
}

Future<void> _startTrip(
  AppBootstrapResult bootstrap,
  String bookingId,
  String pickupCode, {
  required String driverEmail,
  required String driverPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  await expectLater(
    bootstrap.bookingRepository.verifyPickupCode(bookingId, '0000'),
    throwsA(isA<AppFailure>()),
  );
  await bootstrap.bookingRepository.verifyPickupCode(bookingId, pickupCode);
  final booking = await bootstrap.bookingRepository.refreshBooking(bookingId);
  expect(booking.status, BookingStatus.inProgress);
}

Future<void> _completeTrip(
  AppBootstrapResult bootstrap,
  String bookingId, {
  required String driverEmail,
  required String driverPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  await bootstrap.bookingRepository.completeTrip(bookingId);
  final booking = await bootstrap.bookingRepository.refreshBooking(bookingId);
  expect(booking.status, BookingStatus.completed);
  expect(booking.payoutStatus, 'paid');
  expect(booking.driverPayoutCents, 2500);
}

Future<void> _prepareRefund(
  AppBootstrapResult bootstrap, {
  required String driverEmail,
  required String driverPassword,
  required String riderEmail,
  required String riderPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  final origin = await _firstPlace(
    bootstrap,
    'University of California Santa Barbara',
  );
  final destination = await _firstPlace(
    bootstrap,
    'Los Angeles International Airport',
  );
  final ride = await bootstrap.rideRepository.createRide(
    RideDraft(
      origin: origin,
      destination: destination,
      departureAt: DateTime.now().add(const Duration(days: 30)),
      seats: 1,
      pricePerSeatCents: 1800,
      luggageAllowance: LuggageAllowance.backpack,
      genderRestriction: RideGenderRestriction.any,
    ),
  );

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  final request = await bootstrap.bookingRepository.requestSeat(ride.id);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  await bootstrap.bookingRepository.respondToRequest(request.id, accept: true);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('createBookingPayment')
      .call<Map<String, dynamic>>({
        'bookingId': request.id,
        'paymentMethod': 'card',
      });
  final clientSecret = result.data['clientSecret'] as String? ?? '';
  expect(clientSecret, startsWith('pi_'));
  debugPrint(
    'M4_E2E_RESULT=${jsonEncode({'rideId': ride.id, 'bookingId': request.id, 'paymentIntentId': clientSecret.split('_secret_').first})}',
  );
}

Future<void> _verifyRefund(
  AppBootstrapResult bootstrap,
  String bookingId, {
  required String riderEmail,
  required String riderPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  SeatBooking booking = await bootstrap.bookingRepository.refreshBooking(
    bookingId,
  );
  for (var attempt = 0; attempt < 12; attempt++) {
    if (booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.cancelled) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    booking = await bootstrap.bookingRepository.refreshBooking(bookingId);
  }
  final paidTotal = booking.totalCents;
  expect(paidTotal, greaterThan(1800));
  if (booking.status == BookingStatus.confirmed) {
    await bootstrap.bookingRepository.cancelBooking(bookingId);
    booking = await bootstrap.bookingRepository.refreshBooking(bookingId);
  }
  expect(booking.status, BookingStatus.cancelled);
  expect(booking.paymentStatus, 'refunded');
  expect(booking.totalCents, paidTotal);
}

Future<void> _prepareAchPayment(
  AppBootstrapResult bootstrap, {
  required String driverEmail,
  required String driverPassword,
  required String riderEmail,
  required String riderPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  final origin = await _firstPlace(
    bootstrap,
    'University of California Santa Barbara',
  );
  final destination = await _firstPlace(
    bootstrap,
    'Sacramento International Airport',
  );
  final ride = await bootstrap.rideRepository.createRide(
    RideDraft(
      origin: origin,
      destination: destination,
      departureAt: DateTime.now().add(const Duration(days: 45)),
      seats: 1,
      pricePerSeatCents: 2000,
      luggageAllowance: LuggageAllowance.twoPlusBags,
      genderRestriction: RideGenderRestriction.any,
    ),
  );

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  final request = await bootstrap.bookingRepository.requestSeat(ride.id);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  await bootstrap.bookingRepository.respondToRequest(request.id, accept: true);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  final quote = await bootstrap.bookingRepository.quoteBookingPayment(
    request.id,
    BookingPaymentMethod.bank,
  );
  expect(quote.baseFareCents, 2000);
  expect(quote.serviceFeeCents, 160);
  expect(quote.processingFeeCents, greaterThan(0));
  final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('createBookingPayment')
      .call<Map<String, dynamic>>({
        'bookingId': request.id,
        'paymentMethod': 'bank',
      });
  final clientSecret = result.data['clientSecret'] as String? ?? '';
  expect(clientSecret, startsWith('pi_'));
  debugPrint(
    'M4_E2E_RESULT=${jsonEncode({'rideId': ride.id, 'bookingId': request.id, 'paymentIntentId': clientSecret.split('_secret_').first, 'totalCents': quote.totalCents})}',
  );
}

Future<void> _verifyAchPayment(
  AppBootstrapResult bootstrap,
  String bookingId, {
  required String riderEmail,
  required String riderPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  SeatBooking booking = await bootstrap.bookingRepository.refreshBooking(
    bookingId,
  );
  for (var attempt = 0; attempt < 30; attempt++) {
    if (booking.status == BookingStatus.confirmed) break;
    await Future<void>.delayed(const Duration(seconds: 1));
    booking = await bootstrap.bookingRepository.refreshBooking(bookingId);
  }
  expect(booking.status, BookingStatus.confirmed);
  expect(booking.paymentStatus, 'paid');
  expect(booking.totalCents, greaterThan(2160));
}

Future<RidePlacePrediction> _firstPlace(
  AppBootstrapResult bootstrap,
  String query,
) async {
  final matches = await bootstrap.rideRepository.searchPlaces(query);
  expect(matches, isNotEmpty);
  return matches.first;
}
