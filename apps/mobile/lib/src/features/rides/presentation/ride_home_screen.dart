import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/navigation/domain/tab_activation.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/live_trip_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class RideHomeScreen extends ConsumerStatefulWidget {
  const RideHomeScreen({super.key});

  @override
  ConsumerState<RideHomeScreen> createState() => _RideHomeScreenState();
}

class _RideHomeScreenState extends ConsumerState<RideHomeScreen> {
  Future<List<Ride>>? _rides;
  Future<List<SeatBooking>>? _bookings;
  Future<_ActiveRide?>? _activeRide;
  PrimaryRole? _loadedRole;

  void _ensureLoad(PrimaryRole role, {bool forceRefresh = false}) {
    if (!forceRefresh && _rides != null && _loadedRole == role) return;
    _loadedRole = role;
    final repository = ref.read(rideRepositoryProvider);
    _rides = role == PrimaryRole.driver
        ? repository.listMyRides(forceRefresh: forceRefresh)
        : repository.listLeavingSoon(forceRefresh: forceRefresh);
    _bookings = role == PrimaryRole.rider
        ? ref
              .read(bookingRepositoryProvider)
              .listMyBookings(forceRefresh: forceRefresh)
        : Future.value(const <SeatBooking>[]);
    _activeRide = role == PrimaryRole.driver
        ? _findDriverActiveRide(_rides!)
        : _findRiderActiveRide(_bookings!);
  }

  Future<_ActiveRide?> _findDriverActiveRide(Future<List<Ride>> rides) async {
    final values = await rides;
    for (final ride in values) {
      if (ride.status == 'in_progress') {
        return _ActiveRide(ride: ride, isDriver: true);
      }
    }
    return null;
  }

  Future<_ActiveRide?> _findRiderActiveRide(
    Future<List<SeatBooking>> bookingsFuture,
  ) async {
    final bookings = await bookingsFuture;
    final candidates =
        bookings
            .where(
              (booking) =>
                  !const {
                    BookingStatus.pendingDriver,
                    BookingStatus.declined,
                    BookingStatus.acceptedPaymentPending,
                    BookingStatus.paymentProcessing,
                    BookingStatus.expired,
                    BookingStatus.cancelled,
                    BookingStatus.lostSeat,
                    BookingStatus.disputed,
                    BookingStatus.refunded,
                    BookingStatus.cancellationProcessing,
                  }.contains(booking.status) &&
                  (!(booking.status == BookingStatus.completed ||
                          booking.status == BookingStatus.payoutHeld) ||
                      (!booking.riderHasRated &&
                          !booking.ratingPromptDismissed)),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => left.departureAt.compareTo(right.departureAt),
          );
    final repository = ref.read(rideRepositoryProvider);
    for (final booking in candidates) {
      try {
        final plan = await repository.getLiveTrip(booking.rideId);
        repository.invalidateRide(booking.rideId);
        Ride ride;
        try {
          ride = (await repository.getRide(
            booking.rideId,
          )).copyWith(status: 'in_progress');
        } on AppFailure {
          ride = _liveRideFromBooking(booking, plan);
        }
        return _ActiveRide(ride: ride, isDriver: false, riderBooking: booking);
      } on AppFailure catch (failure) {
        if (failure.code == 'failed-precondition') {
          try {
            repository.invalidateRide(booking.rideId);
            final ride = await repository.getRide(booking.rideId);
            if (ride.status == 'in_progress') {
              return _ActiveRide(
                ride: ride,
                isDriver: false,
                riderBooking: booking,
              );
            }
          } on AppFailure {
            continue;
          }
        }
        continue;
      }
    }
    return null;
  }

  Ride _liveRideFromBooking(SeatBooking booking, LiveTripPlan plan) {
    final pickup = booking.pickupLocation;
    final dropoff = booking.dropoffLocation;
    return Ride.fromJson({
      'id': booking.rideId,
      'driverId': booking.driverId,
      'driverName': booking.driverName,
      'driverPhotoUrl': booking.driverPhotoUrl,
      'origin': {
        'placeId': pickup?.placeId ?? '',
        'displayName': booking.originName,
        'formattedAddress': pickup?.formattedAddress ?? booking.originName,
        'latitude': pickup?.latitude ?? 0,
        'longitude': pickup?.longitude ?? 0,
      },
      'destination': {
        'placeId': dropoff?.placeId ?? '',
        'displayName': booking.destinationName,
        'formattedAddress':
            dropoff?.formattedAddress ?? booking.destinationName,
        'latitude': dropoff?.latitude ?? 0,
        'longitude': dropoff?.longitude ?? 0,
      },
      'departureAt': booking.departureAt.toIso8601String(),
      'seatsTotal': 1,
      'seatsAvailable': 0,
      'bookedSeats': 1,
      'pricePerSeatCents': booking.baseFareCents,
      'luggageAllowance': 'backpack',
      'genderRestriction': 'any',
      'status': 'in_progress',
      'encodedPolyline': plan.pickupPolyline,
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeTabActivationProvider, (_, _) {
      if (!mounted) return;
      setState(() {
        _rides = null;
        _bookings = null;
        _activeRide = null;
      });
    });
    final profileState = ref.watch(currentProfileProvider);
    if (profileState.isLoading && !profileState.hasValue) {
      return const RidePageScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final profile = profileState.value;
    final role = profile?.primaryRole ?? PrimaryRole.rider;
    final pendingRequests = role == PrimaryRole.driver
        ? ref.watch(driverPendingRequestCountProvider).value ?? 0
        : 0;
    _ensureLoad(role);
    return RidePageScaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _rides = null;
            _bookings = null;
            _activeRide = null;
          });
          _ensureLoad(role, forceRefresh: true);
          await Future.wait<Object?>([_rides!, _activeRide!]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hey, ${profile?.firstName ?? 'there'}',
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: AppColors.ink,
                      fontSize: 24,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Open profile',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.go(AppRoutes.account),
                    child: RideAvatar(
                      initials: _initials(profile),
                      photoUrl: profile?.photoUrl ?? '',
                      radius: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (role == PrimaryRole.driver)
              _DriverHome(
                rides: _rides!,
                activeRide: _activeRide!,
                profile: profile,
                pendingRequests: pendingRequests,
                onRetry: () => setState(() {
                  _rides = null;
                  _bookings = null;
                  _activeRide = null;
                }),
              )
            else
              _RiderHome(
                rides: _rides!,
                bookings: _bookings!,
                activeRide: _activeRide!,
                onRetry: () => setState(() {
                  _rides = null;
                  _bookings = null;
                  _activeRide = null;
                }),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(UserProfile? profile) {
    if (profile == null) return 'SC';
    return [profile.firstName, profile.lastName]
        .where((value) => value.isNotEmpty)
        .map((value) => value[0].toUpperCase())
        .join();
  }
}

class _RiderHome extends StatelessWidget {
  const _RiderHome({
    required this.rides,
    required this.bookings,
    required this.activeRide,
    required this.onRetry,
  });

  final Future<List<Ride>> rides;
  final Future<List<SeatBooking>> bookings;
  final Future<_ActiveRide?> activeRide;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => context.go(AppRoutes.searchRides),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.softSurface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              children: [
                FinalDraftAssetIcon('search', color: AppColors.mutedInk),
                SizedBox(width: 8),
                Text('Where to?', style: TextStyle(color: AppColors.mutedInk)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _LiveRideSection(activeRide: activeRide),
        _UpcomingBookingsSection(bookings: bookings),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push(AppRoutes.leavingSoon),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Leaving soon',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: FinalDraftChevronIcon(size: 17),
              ),
            ],
          ),
        ),
        FutureBuilder<List<Ride>>(
          future: rides,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _RideLoadError(onRetry: onRetry);
            }
            final now = DateTime.now();
            final values = (snapshot.data ?? const <Ride>[])
                .where(
                  (ride) =>
                      ride.status == 'published' &&
                      !ride.departureAt.isBefore(now),
                )
                .toList();
            if (values.isEmpty) {
              return const _EmptyRides(
                title: 'No rides leaving soon',
                message: 'Try a route and date to find the right ride.',
              );
            }
            return Column(
              children: [
                for (final ride in values.take(3)) ...[
                  _RiderLeavingSoonRideCard(
                    ride: ride,
                    onTap: () => context.push('/rides/${ride.id}'),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RiderLeavingSoonRideCard extends StatelessWidget {
  const _RiderLeavingSoonRideCard({required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RideCard(ride: ride, onTap: onTap);
}

class _UpcomingBookingsSection extends StatelessWidget {
  const _UpcomingBookingsSection({required this.bookings});

  final Future<List<SeatBooking>> bookings;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SeatBooking>>(
    future: bookings,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done ||
          snapshot.hasError) {
        return const SizedBox.shrink();
      }
      final now = DateTime.now();
      final values =
          (snapshot.data ?? const <SeatBooking>[])
              .where(
                (booking) =>
                    !booking.departureAt.isBefore(now) &&
                    booking.status == BookingStatus.confirmed &&
                    booking.paymentStatus == 'paid',
              )
              .toList(growable: false)
            ..sort(
              (left, right) => left.departureAt.compareTo(right.departureAt),
            );
      if (values.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              values.length == 1 ? 'Upcoming trip' : 'Upcoming trips',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final booking in values.take(2)) ...[
              RideSummaryCard(
                origin: booking.originName,
                destination: booking.destinationName,
                dateLabel: formatShortDate(booking.departureAt),
                timeLabel: formatTime(booking.departureAt),
                priceLabel: '\$${(booking.baseFareCents / 100).round()}',
                bookedLabel: 'Confirmed',
                profileName: booking.driverName,
                profileInitials: booking.driverName
                    .split(' ')
                    .take(2)
                    .map((part) => part.isEmpty ? '' : part[0])
                    .join(),
                profilePhotoUrl: booking.driverPhotoUrl,
                keyPrefix: 'home-booking-${booking.id}',
                onTap: () => context.push('/rides/${booking.rideId}'),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    },
  );
}

class _DriverHome extends StatelessWidget {
  const _DriverHome({
    required this.rides,
    required this.activeRide,
    required this.profile,
    required this.pendingRequests,
    required this.onRetry,
  });

  final Future<List<Ride>> rides;
  final Future<_ActiveRide?> activeRide;
  final UserProfile? profile;
  final int pendingRequests;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => context.go(AppRoutes.postRide),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Post your next ride',
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const FinalDraftAssetIcon('add-square', size: 40),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: _money(profile?.totalEarningsCents ?? 0),
                label: 'Total reimbursed',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '${profile?.tripCount ?? 0}',
                label: 'Total trips',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _LiveRideSection(activeRide: activeRide),
        Row(
          children: [
            Expanded(
              child: Text(
                'Your upcoming ride',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: AppColors.ink,
                  fontSize: 18,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (pendingRequests > 0) ...[
              const SizedBox(width: 8),
              Semantics(
                label: '$pendingRequests new seat requests',
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE14942),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 9, height: 9),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Ride>>(
          future: rides,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _RideLoadError(onRetry: onRetry);
            final now = DateTime.now();
            final values = (snapshot.data ?? const <Ride>[])
                .where(
                  (ride) =>
                      ride.status == 'published' &&
                      !ride.departureAt.isBefore(now),
                )
                .toList();
            if (values.isEmpty) {
              return const _EmptyRides(
                title: 'No upcoming rides',
                message: 'Post a ride when you know your next trip.',
              );
            }
            return Column(
              children: [
                for (var index = 0; index < values.length; index++) ...[
                  _DriverUpcomingRideCard(
                    ride: values[index],
                    onTap: () => context.push('/rides/${values[index].id}'),
                  ),
                  if (index != values.length - 1) const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  String _money(int cents) {
    final dollars = cents / 100;
    return dollars == dollars.roundToDouble()
        ? '\$${dollars.toStringAsFixed(0)}'
        : '\$${dollars.toStringAsFixed(2)}';
  }
}

class _DriverUpcomingRideCard extends StatelessWidget {
  const _DriverUpcomingRideCard({required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RideSummaryCard(
    key: ValueKey('driver-upcoming-card-${ride.id}'),
    origin: ride.origin.displayName,
    destination: ride.destination.displayName,
    dateLabel: _displayDate(ride.departureAt),
    timeLabel: formatTime(ride.departureAt),
    priceLabel: ride.priceLabel,
    bookedLabel: '${ride.bookedSeats}/${ride.seatsTotal} booked',
    keyPrefix: 'driver-upcoming-${ride.id}',
    onTap: onTap,
  );

  String _displayDate(DateTime value) {
    return formatShortDate(value);
  }
}

class _ActiveRide {
  const _ActiveRide({
    required this.ride,
    required this.isDriver,
    this.riderBooking,
  });

  final Ride ride;
  final bool isDriver;
  final SeatBooking? riderBooking;
}

class _LiveRideSection extends StatelessWidget {
  const _LiveRideSection({required this.activeRide});

  final Future<_ActiveRide?> activeRide;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ActiveRide?>(
      future: activeRide,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || value == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Live Ride', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Open live ride',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => LiveTripScreen(
                        ride: value.ride,
                        isDriver: value.isDriver,
                        riderBooking: value.riderBooking,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF52A779),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${value.ride.origin.displayName} → ${value.ride.destination.displayName}',
                                softWrap: true,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                value.isDriver
                                    ? 'Trip in progress · View route and riders'
                                    : 'Trip in progress · View live ride details',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const FinalDraftChevronIcon(
                          size: 17,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: AppColors.ink,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: AppColors.mutedInk,
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _RideLoadError extends StatelessWidget {
  const _RideLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Text(
            'We could not load rides.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _EmptyRides extends StatelessWidget {
  const _EmptyRides({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
