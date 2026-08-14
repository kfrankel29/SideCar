import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
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
  Future<_ActiveRide?>? _activeRide;
  PrimaryRole? _loadedRole;

  void _ensureLoad(PrimaryRole role, {bool forceRefresh = false}) {
    if (!forceRefresh && _rides != null && _loadedRole == role) return;
    _loadedRole = role;
    final repository = ref.read(rideRepositoryProvider);
    _rides = role == PrimaryRole.driver
        ? repository.listMyRides(forceRefresh: forceRefresh)
        : repository.listLeavingSoon(forceRefresh: forceRefresh);
    _activeRide = role == PrimaryRole.driver
        ? _findDriverActiveRide(_rides!)
        : _findRiderActiveRide(forceRefresh: forceRefresh);
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

  Future<_ActiveRide?> _findRiderActiveRide({
    required bool forceRefresh,
  }) async {
    final bookings = await ref
        .read(bookingRepositoryProvider)
        .listMyBookings(forceRefresh: forceRefresh);
    final candidates =
        bookings
            .where(
              (booking) => !const {
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
              }.contains(booking.status),
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
    final profileState = ref.watch(currentProfileProvider);
    if (profileState.isLoading && !profileState.hasValue) {
      return const RidePageScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final profile = profileState.value;
    final role = profile?.primaryRole ?? PrimaryRole.rider;
    _ensureLoad(role);
    return RidePageScaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _rides = null;
            _activeRide = null;
          });
          _ensureLoad(role, forceRefresh: true);
          await Future.wait<Object?>([_rides!, _activeRide!]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hey, ${profile?.firstName ?? 'there'}',
                    style: Theme.of(context).textTheme.headlineLarge,
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
                      radius: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (role == PrimaryRole.driver)
              _DriverHome(
                rides: _rides!,
                activeRide: _activeRide!,
                profile: profile,
                onRetry: () => setState(() {
                  _rides = null;
                  _activeRide = null;
                }),
              )
            else
              _RiderHome(
                rides: _rides!,
                activeRide: _activeRide!,
                onRetry: () => setState(() {
                  _rides = null;
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
    required this.activeRide,
    required this.onRetry,
  });

  final Future<List<Ride>> rides;
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
                Icon(Icons.search_rounded, color: AppColors.mutedInk),
                SizedBox(width: 8),
                Text('Where to?', style: TextStyle(color: AppColors.mutedInk)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _LiveRideSection(activeRide: activeRide),
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
                child: Icon(Icons.chevron_right_rounded),
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
                  RideCard(
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

class _DriverHome extends StatelessWidget {
  const _DriverHome({
    required this.rides,
    required this.activeRide,
    required this.profile,
    required this.onRetry,
  });

  final Future<List<Ride>> rides;
  final Future<_ActiveRide?> activeRide;
  final UserProfile? profile;
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
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Post your next ride',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A292F),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: _money(profile?.totalEarningsCents ?? 0),
                label: 'Total Earnings',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value:
                    '${(profile?.rating ?? 0) > 0 ? profile!.rating.toStringAsFixed(1) : '—'} · ${profile?.tripCount ?? 0}',
                label: 'Rating · trips',
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        _LiveRideSection(activeRide: activeRide),
        Text(
          'Your upcoming rides',
          style: Theme.of(context).textTheme.titleLarge,
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
                  InkWell(
                    onTap: () => context.push('/rides/${values[index].id}'),
                    child: Container(
                      height: 150,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RideRouteCard(
                        origin: values[index].origin.displayName,
                        destination: values[index].destination.displayName,
                        originSubtitle:
                            '${formatShortDate(values[index].departureAt)} · ${formatTime(values[index].departureAt)}',
                        destinationSubtitle: 'Upcoming',
                      ),
                    ),
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
                      color: AppColors.softSurface,
                      border: Border.all(color: AppColors.border),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                value.isDriver
                                    ? 'Trip in progress · View route and riders'
                                    : 'Trip in progress · View live ride details',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded),
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
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
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
