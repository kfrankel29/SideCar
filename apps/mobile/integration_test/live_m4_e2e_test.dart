import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/ride_home_screen.dart';
import 'package:sidecar/src/theme/app_theme.dart';

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
      case 'interactive-payment-start-trip':
        await _verifyInteractivePaymentAndPickup(
          bootstrap,
          tester: tester,
          driverEmail: driverEmail,
          driverPassword: driverPassword,
          riderEmail: riderEmail,
          riderPassword: riderPassword,
        );
        return;
      case 'verify-live-home':
        await bootstrap.authRepository.signOut();
        await _signIn(bootstrap, email: driverEmail, password: driverPassword);
        await _verifyLiveRideHomeEntry(
          tester: tester,
          bootstrap: bootstrap,
          isDriver: true,
        );
        await bootstrap.authRepository.signOut();
        await _signIn(bootstrap, email: riderEmail, password: riderPassword);
        await _verifyLiveRideHomeEntry(
          tester: tester,
          bootstrap: bootstrap,
          isDriver: false,
        );
        return;
      case 'verify-immediate-post':
        await _verifyImmediateRidePost(
          bootstrap,
          driverEmail: driverEmail,
          driverPassword: driverPassword,
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
      case 'feedback-rules':
        await _verifyFeedbackRules(
          bootstrap,
          driverEmail: driverEmail,
          driverPassword: driverPassword,
          riderEmail: riderEmail,
          riderPassword: riderPassword,
        );
        return;
      default:
        fail('Set M4_E2E_PHASE to a supported live test phase.');
    }
  });
}

Future<void> _verifyImmediateRidePost(
  AppBootstrapResult bootstrap, {
  required String driverEmail,
  required String driverPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await _signIn(bootstrap, email: driverEmail, password: driverPassword);
  final origin = await _firstPlace(
    bootstrap,
    'University of California Santa Barbara',
  );
  final destination = await _firstPlace(bootstrap, 'Santa Barbara Airport');
  final requestedDeparture = DateTime.now().add(const Duration(seconds: 5));
  Ride? ride;
  try {
    ride = await bootstrap.rideRepository.createRide(
      RideDraft(
        origin: origin,
        destination: destination,
        departureAt: requestedDeparture,
        seats: 1,
        pricePerSeatCents: 100,
        luggageAllowance: LuggageAllowance.backpack,
        genderRestriction: RideGenderRestriction.any,
      ),
    );
    expect(
      ride.departureAt.difference(requestedDeparture).abs(),
      lessThan(const Duration(minutes: 1)),
    );
  } finally {
    if (ride != null) {
      await bootstrap.rideRepository.cancelRide(ride.id);
    }
  }
}

Future<void> _verifyInteractivePaymentAndPickup(
  AppBootstrapResult bootstrap, {
  required WidgetTester tester,
  required String driverEmail,
  required String driverPassword,
  required String riderEmail,
  required String riderPassword,
}) async {
  await bootstrap.authRepository.signOut();
  await _signIn(bootstrap, email: driverEmail, password: driverPassword);
  const appCheckRegistrationPause = int.fromEnvironment(
    'M4_E2E_APP_CHECK_PAUSE_SECONDS',
  );
  if (appCheckRegistrationPause > 0) {
    await Future<void>.delayed(Duration(seconds: appCheckRegistrationPause));
  }
  Ride? ride;
  SeatBooking? requested;
  try {
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
    ride = await bootstrap.rideRepository.createRide(
      RideDraft(
        origin: origin,
        destination: destination,
        departureAt: DateTime.now().add(const Duration(days: 100)),
        seats: 1,
        pricePerSeatCents: 2500,
        luggageAllowance: LuggageAllowance.oneSuitcase,
        genderRestriction: RideGenderRestriction.any,
      ),
    );

    await bootstrap.authRepository.signOut();
    await _signIn(bootstrap, email: riderEmail, password: riderPassword);
    requested = await bootstrap.bookingRepository.requestSeat(
      SeatRequest(
        rideId: ride.id,
        seat: BookingSeat.front,
        pickupPlaceId: ride.origin.placeId,
        dropoffPlaceId: ride.destination.placeId,
      ),
    );

    await bootstrap.authRepository.signOut();
    await _signIn(bootstrap, email: driverEmail, password: driverPassword);
    final accepted = await bootstrap.bookingRepository.respondToRequest(
      requested.id,
      accept: true,
    );
    expect(accepted.status, BookingStatus.acceptedPaymentPending);

    await bootstrap.authRepository.signOut();
    await _signIn(bootstrap, email: riderEmail, password: riderPassword);
    final paid = await bootstrap.bookingRepository.payForBooking(
      requested.id,
      BookingPaymentMethod.card,
    );
    expect(paid.status, BookingStatus.confirmed);
    expect(paid.paymentStatus, 'paid');
    expect(paid.pickupCode, matches(RegExp(r'^\d{4}$')));
    final pickupCode = paid.pickupCode!;

    await bootstrap.authRepository.signOut();
    await _signIn(bootstrap, email: driverEmail, password: driverPassword);
    final driverPlan = await bootstrap.rideRepository.startLiveTrip(ride.id);
    expect(driverPlan.phase, LiveTripPhase.pickups);
    expect(driverPlan.pickupStops, hasLength(1));
    expect(driverPlan.dropoffStops, hasLength(1));
    expect(driverPlan.pickupStops.single.bookingId, requested.id);
    expect(driverPlan.dropoffStops.single.bookingId, requested.id);
    expect(driverPlan.pickupStops.single.riderName, isNotEmpty);
    expect(driverPlan.pickupStops.single.eta, isNotNull);
    expect(driverPlan.dropoffStops.single.eta, isNotNull);
    await _verifyLiveRideHomeEntry(
      tester: tester,
      bootstrap: bootstrap,
      isDriver: true,
    );

    await bootstrap.authRepository.signOut();
    await _signIn(bootstrap, email: riderEmail, password: riderPassword);
    final riderPlan = await bootstrap.rideRepository.getLiveTrip(ride.id);
    expect(riderPlan.pickupStops.single.bookingId, requested.id);
    expect(riderPlan.dropoffStops.single.bookingId, requested.id);
    await _verifyLiveRideHomeEntry(
      tester: tester,
      bootstrap: bootstrap,
      isDriver: false,
    );

    await bootstrap.authRepository.signOut();
    await _signIn(bootstrap, email: driverEmail, password: driverPassword);
    final wrongCode = pickupCode == '0000' ? '1111' : '0000';
    await expectLater(
      bootstrap.bookingRepository.verifyPickupCode(requested.id, wrongCode),
      throwsA(isA<AppFailure>()),
    );
    await bootstrap.bookingRepository.verifyPickupCode(
      requested.id,
      pickupCode,
    );
    final started = await bootstrap.bookingRepository.refreshBooking(
      requested.id,
    );
    expect(started.status, BookingStatus.inProgress);
    final dropoffPlan = await bootstrap.rideRepository.getLiveTrip(ride.id);
    expect(dropoffPlan.phase, LiveTripPhase.dropoffs);
    expect(dropoffPlan.pickupStops.single.completedAt, isNotNull);
    expect(dropoffPlan.dropoffStops.single.bookingId, requested.id);
    debugPrint(
      'M4_E2E_RESULT=${jsonEncode({'rideId': ride.id, 'bookingId': requested.id, 'payment': 'paid', 'liveTrip': 'visible-to-both-roles', 'pickup': 'verified', 'phase': dropoffPlan.phase.name, 'status': started.status.wireValue})}',
    );
  } finally {
    if (ride != null && requested == null) {
      await bootstrap.authRepository.signOut();
      await _signIn(bootstrap, email: driverEmail, password: driverPassword);
      await bootstrap.rideRepository.cancelRide(ride.id);
    }
  }
}

Future<void> _verifyLiveRideHomeEntry({
  required WidgetTester tester,
  required AppBootstrapResult bootstrap,
  required bool isDriver,
}) async {
  final profile = await bootstrap.profileRepository.loadCurrentProfile();
  expect(profile, isNotNull);
  runApp(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authRepositoryProvider.overrideWithValue(bootstrap.authRepository),
        currentProfileProvider.overrideWith(
          (ref) => Stream.value(
            profile!.copyWith(
              primaryRole: isDriver ? PrimaryRole.driver : PrimaryRole.rider,
            ),
          ),
        ),
        rideRepositoryProvider.overrideWithValue(bootstrap.rideRepository),
        bookingRepositoryProvider.overrideWithValue(
          bootstrap.bookingRepository,
        ),
      ],
      child: MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const RideHomeScreen(),
      ),
    ),
  );
  await tester.pump();
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (find.text('Live Ride').evaluate().isEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }

  expect(find.text('Live Ride'), findsOneWidget);
  final followingSection = isDriver ? 'Your upcoming rides' : 'Leaving soon';
  final liveRideTop = tester.getTopLeft(find.text('Live Ride')).dy;
  final followingTop = tester.getTopLeft(find.text(followingSection)).dy;
  expect(liveRideTop, lessThan(followingTop));

  final entry = isDriver
      ? find.text('Trip in progress · View route and riders')
      : find.text('Trip in progress · View live ride details');
  expect(entry, findsOneWidget);
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  final liveScreenDeadline = DateTime.now().add(const Duration(seconds: 15));
  while (find.text('Live trip').evaluate().isEmpty &&
      DateTime.now().isBefore(liveScreenDeadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(find.text('Live trip'), findsOneWidget);
  expect(find.text('Pickup order'), findsOneWidget);
  expect(find.text('Drop-off order'), findsOneWidget);
  expect(find.textContaining('Honda'), findsWidgets);
}

Future<void> _signIn(
  AppBootstrapResult bootstrap, {
  required String email,
  required String password,
}) async {
  await bootstrap.authRepository.signIn(email: email, password: password);
  final user = FirebaseAuth.instance.currentUser;
  expect(user, isNotNull);
  final token = await user!.getIdToken(true);
  expect(token, isNotEmpty);
  await Future<void>.delayed(const Duration(milliseconds: 250));
}

Future<void> _verifyFeedbackRules(
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
  final departure = DateTime.now().add(
    Duration(
      days: 220,
      seconds: DateTime.now().millisecondsSinceEpoch.remainder(18000),
    ),
  );
  final womenOnlyRide = await bootstrap.rideRepository.createRide(
    RideDraft(
      origin: origin,
      destination: destination,
      departureAt: departure,
      seats: 2,
      pricePerSeatCents: 2000,
      luggageAllowance: LuggageAllowance.backpack,
      genderRestriction: RideGenderRestriction.womenOnly,
    ),
  );
  final secondRide = await bootstrap.rideRepository.createRide(
    RideDraft(
      origin: origin,
      destination: destination,
      departureAt: departure.add(const Duration(days: 2)),
      seats: 3,
      pricePerSeatCents: 2200,
      luggageAllowance: LuggageAllowance.oneSuitcase,
      genderRestriction: RideGenderRestriction.any,
    ),
  );
  final driverRides = await bootstrap.rideRepository.listMyRides(
    forceRefresh: true,
  );
  expect(driverRides.any((ride) => ride.id == womenOnlyRide.id), isTrue);
  expect(driverRides.any((ride) => ride.id == secondRide.id), isTrue);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  final riderProfile = await bootstrap.profileRepository.loadCurrentProfile();
  expect(riderProfile, isNotNull);
  await bootstrap.profileRepository.saveProfile(
    riderProfile!.copyWith(gender: 'Male'),
  );
  final seatRequest = SeatRequest(
    rideId: womenOnlyRide.id,
    seat: BookingSeat.front,
    pickupPlaceId: womenOnlyRide.origin.placeId,
    dropoffPlaceId: womenOnlyRide.destination.placeId,
  );
  await expectLater(
    bootstrap.bookingRepository.requestSeat(seatRequest),
    throwsA(
      isA<AppFailure>().having(
        (failure) => failure.code,
        'code',
        'permission-denied',
      ),
    ),
  );
  await bootstrap.profileRepository.saveProfile(
    riderProfile.copyWith(gender: 'Female'),
  );
  final request = await bootstrap.bookingRepository.requestSeat(seatRequest);
  expect(request.status, BookingStatus.pendingDriver);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  final requests = await bootstrap.bookingRepository.listRideRequests(
    rideId: womenOnlyRide.id,
    forceRefresh: true,
  );
  expect(
    requests.any(
      (booking) =>
          booking.id == request.id &&
          booking.status == BookingStatus.pendingDriver,
    ),
    isTrue,
  );
  await bootstrap.safetyRepository.blockUser(request.riderId);
  expect(await bootstrap.safetyRepository.isBlocked(request.riderId), isTrue);
  final removedRequest = await bootstrap.bookingRepository.refreshBooking(
    request.id,
  );
  expect(removedRequest.status, BookingStatus.cancelled);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  await expectLater(
    bootstrap.bookingRepository.requestSeat(seatRequest),
    throwsA(
      isA<AppFailure>().having(
        (failure) => failure.code,
        'code',
        'permission-denied',
      ),
    ),
  );

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  await bootstrap.safetyRepository.unblockUser(request.riderId);
  expect(await bootstrap.safetyRepository.isBlocked(request.riderId), isFalse);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: riderEmail,
    password: riderPassword,
  );
  final unblockedRequest = await bootstrap.bookingRepository.requestSeat(
    seatRequest,
  );
  expect(unblockedRequest.status, BookingStatus.pendingDriver);

  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: driverEmail,
    password: driverPassword,
  );
  await bootstrap.safetyRepository.blockUser(unblockedRequest.riderId);
  await bootstrap.safetyRepository.unblockUser(unblockedRequest.riderId);
  await bootstrap.rideRepository.cancelRide(womenOnlyRide.id);
  await bootstrap.rideRepository.cancelRide(secondRide.id);
  debugPrint(
    'M4_E2E_RESULT=${jsonEncode({'womenOnlyRide': true, 'driverRideRefresh': true, 'blockRemoval': true, 'unblock': true})}',
  );
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
      departureAt: DateTime.now().add(const Duration(days: 80)),
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
  final request = await bootstrap.bookingRepository.requestSeat(
    SeatRequest(
      rideId: ride.id,
      seat: BookingSeat.front,
      pickupPlaceId: ride.origin.placeId,
      dropoffPlaceId: ride.destination.placeId,
    ),
  );
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
  final booking = await bootstrap.bookingRepository.refreshBooking(bookingId);
  final initialPlan = await bootstrap.rideRepository.startLiveTrip(
    booking.rideId,
  );
  expect(initialPlan.phase, LiveTripPhase.pickups);
  await expectLater(
    bootstrap.bookingRepository.verifyPickupCode(bookingId, '0000'),
    throwsA(isA<AppFailure>()),
  );
  await bootstrap.bookingRepository.verifyPickupCode(bookingId, pickupCode);
  final started = await bootstrap.bookingRepository.refreshBooking(bookingId);
  expect(started.status, BookingStatus.inProgress);
  final dropoffPlan = await bootstrap.rideRepository.getLiveTrip(
    booking.rideId,
  );
  expect(dropoffPlan.phase, LiveTripPhase.dropoffs);
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
      departureAt: DateTime.now().add(const Duration(days: 120)),
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
  final request = await bootstrap.bookingRepository.requestSeat(
    SeatRequest(
      rideId: ride.id,
      seat: BookingSeat.rearLeft,
      pickupPlaceId: ride.origin.placeId,
      dropoffPlaceId: ride.destination.placeId,
    ),
  );

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

Future<RidePlacePrediction> _firstPlace(
  AppBootstrapResult bootstrap,
  String query,
) async {
  final matches = await bootstrap.rideRepository.searchPlaces(query);
  expect(matches, isNotEmpty);
  return matches.first;
}
