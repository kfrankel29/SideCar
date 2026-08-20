import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
import 'package:sidecar/src/features/bookings/presentation/trip_rating_screen.dart';
import 'package:sidecar/src/features/messaging/domain/messaging_repository.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/place_picker_sheet.dart';
import 'package:sidecar/src/features/rides/presentation/live_trip_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class RideDetailsScreen extends ConsumerStatefulWidget {
  const RideDetailsScreen({required this.rideId, super.key});

  final String rideId;

  @override
  ConsumerState<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends ConsumerState<RideDetailsScreen> {
  late Future<_RideDetailsPayload> _details;
  bool _requesting = false;
  BookingSeat _selectedSeat = BookingSeat.front;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _details = _loadDetails();
  }

  Future<_RideDetailsPayload> _loadDetails() async {
    final repository = ref.read(rideRepositoryProvider);
    repository.invalidateRide(widget.rideId);
    final ride = await repository.getRide(widget.rideId);
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null || userId == ride.driverId) {
      return _RideDetailsPayload(ride: ride);
    }
    List<SeatBooking> bookings;
    try {
      bookings = await ref
          .read(bookingRepositoryProvider)
          .listMyBookings(forceRefresh: true);
    } on AppFailure {
      bookings = const [];
    }
    for (final booking in bookings) {
      if (booking.rideId == ride.id &&
          const {
            BookingStatus.confirmed,
            BookingStatus.inProgress,
            BookingStatus.completed,
            BookingStatus.payoutHeld,
          }.contains(booking.status)) {
        return _RideDetailsPayload(ride: ride, booking: booking);
      }
    }
    return _RideDetailsPayload(ride: ride);
  }

  Future<void> _cancelRide(Ride ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this ride?'),
        content: const Text(
          'The ride will be removed from search and can no longer accept riders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep ride'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel ride'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(bookingRepositoryProvider).cancelDriverRide(ride.id);
      if (mounted) {
        ref.read(rideRepositoryProvider).invalidateRide(ride.id);
        showAppNotice(
          context,
          'Ride cancelled. Confirmed riders were refunded.',
        );
        context.pop();
      }
    } on AppFailure catch (error) {
      if (!mounted) return;
      showAppNotice(context, error.message, kind: AppNoticeKind.error);
    }
  }

  Future<void> _requestSeat(Ride ride) async {
    final request = await showModalBottomSheet<SeatRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _SeatRequestSheet(ride: ride, selectedSeat: _selectedSeat),
    );
    if (request == null || !mounted) return;
    setState(() => _requesting = true);
    try {
      await ref.read(bookingRepositoryProvider).requestSeat(request);
      if (!mounted) return;
      showAppNotice(context, 'Seat request sent. The driver will review it.');
      context.pop();
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_RideDetailsPayload>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            final message = snapshot.error is AppFailure
                ? (snapshot.error! as AppFailure).message
                : 'That ride is no longer available.';
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final details = snapshot.data!;
          final ride = details.ride;
          final isOwner =
              ref.read(authRepositoryProvider).currentUser?.id == ride.driverId;
          return _RideDetails(
            ride: ride,
            isOwner: isOwner,
            onCancel: () => _cancelRide(ride),
            requesting: _requesting,
            onRequest: () => _requestSeat(ride),
            selectedSeat: _selectedSeat,
            onSeatSelected: (seat) => setState(() => _selectedSeat = seat),
            booking: details.booking,
          );
        },
      ),
    );
  }
}

class _RideDetailsPayload {
  const _RideDetailsPayload({required this.ride, this.booking});

  final Ride ride;
  final SeatBooking? booking;
}

class _RideDetails extends StatelessWidget {
  const _RideDetails({
    required this.ride,
    required this.isOwner,
    required this.onCancel,
    required this.requesting,
    required this.onRequest,
    required this.selectedSeat,
    required this.onSeatSelected,
    required this.booking,
  });

  final Ride ride;
  final bool isOwner;
  final VoidCallback onCancel;
  final bool requesting;
  final VoidCallback onRequest;
  final BookingSeat selectedSeat;
  final ValueChanged<BookingSeat> onSeatSelected;
  final SeatBooking? booking;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    if (isOwner) {
      if (ride.status == 'in_progress') {
        return LiveTripScreen(ride: ride, isDriver: true);
      }
      return _OwnerRideDetailsPage(ride: ride, onCancel: onCancel);
    }
    if (ride.status == 'in_progress' && booking != null) {
      return LiveTripScreen(ride: ride, isDriver: false, riderBooking: booking);
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  RideMapPreview(
                    mapPreviewUrl: ride.mapPreviewUrl,
                    topExtension: topInset,
                  ),
                  Positioned(
                    left: 18,
                    top: topInset + 8,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: context.pop,
                        icon: const FinalDraftBackIcon(size: 23),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => context.push('/profiles/${ride.driverId}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            RideAvatar(
                              initials: ride.driverInitials,
                              photoUrl: ride.driverPhotoUrl,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ride.driverName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      if (ride.driverRating > 0)
                                        '★ ${ride.driverRating.toStringAsFixed(1)}',
                                      '${ride.driverTrips} trips',
                                      if (ride.vehicle.makeAndModel.isNotEmpty)
                                        ride.vehicle.makeAndModel,
                                    ].join(' · '),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 116,
                      child: RideRouteCard(
                        origin: ride.origin.displayName,
                        destination: ride.destination.displayName,
                        originSubtitle:
                            '${formatShortDate(ride.departureAt)} · ${formatTime(ride.departureAt)}',
                        destinationSubtitle:
                            'ETA ${formatTime(ride.departureAt.add(Duration(seconds: ride.durationSeconds)))}',
                        backgroundColor: AppColors.softSurface,
                        showBorder: false,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (booking != null) ...[
                      _BookedTripDetails(booking: booking!),
                      const SizedBox(height: 22),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pick your seat',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          'Same price, any seat',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    _SeatDiagram(
                      ride: ride,
                      selectedSeat: booking?.seat ?? selectedSeat,
                      onSelected: booking == null ? onSeatSelected : (_) {},
                      interactive: booking == null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailValue(
                            label: 'Luggage per rider',
                            value: ride.luggageAllowance.label,
                          ),
                        ),
                        Expanded(
                          child: _DetailValue(
                            label: 'Rider preference',
                            value: ride.genderRestriction.label,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(24, 13, 24, 12 + bottomInset),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.softSurface)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking == null
                          ? '${ride.priceLabel} / seat'
                          : _bookedTripTitle(booking!),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(
                      booking == null
                          ? '${selectedSeat.label} seat · ${ride.seatsAvailable} of ${ride.seatsTotal} left'
                          : '${booking!.seat.label} seat · ${_bookedTripStatus(booking!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: _RiderRideAction(
                  ride: ride,
                  booking: booking,
                  requesting: requesting,
                  onRequest: onRequest,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _bookedTripTitle(SeatBooking booking) => switch (booking.status) {
  BookingStatus.inProgress => 'Trip in progress',
  BookingStatus.completed => 'Trip complete',
  BookingStatus.payoutHeld => 'Trip complete',
  _ => 'Your ride',
};

String _bookedTripStatus(SeatBooking booking) => switch (booking.status) {
  BookingStatus.inProgress => 'In progress',
  BookingStatus.completed => 'Completed',
  BookingStatus.payoutHeld => 'Completed',
  _ => 'Confirmed',
};

class _RiderRideAction extends StatelessWidget {
  const _RiderRideAction({
    required this.ride,
    required this.booking,
    required this.requesting,
    required this.onRequest,
  });

  final Ride ride;
  final SeatBooking? booking;
  final bool requesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final current = booking;
    if (current == null) {
      return FilledButton(
        onPressed: requesting || ride.seatsAvailable < 1
            ? null
            : AppHaptics.wrap(onRequest),
        child: Text(requesting ? 'Sending…' : 'Request seat'),
      );
    }
    if (current.status == BookingStatus.confirmed) {
      return FilledButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => PickupCodeScreen(booking: current)),
        ),
        child: const Text('View pickup code'),
      );
    }
    if ({
          BookingStatus.completed,
          BookingStatus.payoutHeld,
        }.contains(current.status) &&
        !current.riderHasRated) {
      return FilledButton(
        onPressed: () => Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => TripRatingScreen(booking: current)),
        ),
        child: const Text('Rate trip'),
      );
    }
    return FilledButton(
      onPressed: null,
      child: Text(_bookedTripStatus(current)),
    );
  }
}

class _BookedTripDetails extends StatelessWidget {
  const _BookedTripDetails({required this.booking});

  final SeatBooking booking;

  @override
  Widget build(BuildContext context) {
    final pickup = booking.pickupLocation;
    final dropoff = booking.dropoffLocation;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your trip', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (pickup != null)
            Text(
              'Pickup · ${pickup.formattedAddress}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (pickup != null && dropoff != null) const SizedBox(height: 5),
          if (dropoff != null)
            Text(
              'Drop-off · ${dropoff.formattedAddress}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _OwnerRideDetailsPage extends ConsumerStatefulWidget {
  const _OwnerRideDetailsPage({required this.ride, required this.onCancel});

  final Ride ride;
  final VoidCallback onCancel;

  @override
  ConsumerState<_OwnerRideDetailsPage> createState() =>
      _OwnerRideDetailsPageState();
}

class _OwnerRideDetailsPageState extends ConsumerState<_OwnerRideDetailsPage> {
  late Future<List<SeatBooking>> _bookings;
  bool _startingTrip = false;
  bool _openingRatings = false;

  @override
  void initState() {
    super.initState();
    _reloadBookings();
  }

  void _reloadBookings() {
    _bookings = ref
        .read(bookingRepositoryProvider)
        .listRideRequests(rideId: widget.ride.id, forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final booked = ride.bookedSeats;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 17, 24, 24),
              children: [
                SizedBox(
                  height: 86,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        left: 0,
                        top: 2,
                        child: IconButton(
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          onPressed: context.pop,
                          icon: const FinalDraftBackIcon(size: 23),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'Your ride',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatShortDate(ride.departureAt)} · ${formatTime(ride.departureAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 9),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '$booked/${ride.seatsTotal} booked',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RideMapPreview(mapPreviewUrl: ride.mapPreviewUrl),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 116,
                  child: RideRouteCard(
                    origin: ride.origin.displayName,
                    destination: ride.destination.displayName,
                    originSubtitle: 'Dep ${formatTime(ride.departureAt)}',
                    destinationSubtitle:
                        'ETA ${formatTime(ride.departureAt.add(Duration(seconds: ride.durationSeconds)))}',
                    backgroundColor: AppColors.softSurface,
                    showBorder: false,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _DetailValue(
                        label: 'Price / seat',
                        value: ride.priceLabel,
                      ),
                    ),
                    Expanded(
                      child: _DetailValue(
                        label: 'Luggage per rider',
                        value: ride.luggageAllowance.label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DetailValue(
                        label: 'Rider preference',
                        value: ride.genderRestriction.label,
                      ),
                    ),
                    if (ride.vehicle.makeAndModel.isNotEmpty)
                      Expanded(
                        child: _DetailValue(
                          label: 'Vehicle',
                          value: ride.vehicle.makeAndModel,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 36),
                Text(
                  'Your riders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<SeatBooking>>(
                  future: _bookings,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final riders = (snapshot.data ?? const <SeatBooking>[])
                        .where(
                          (booking) => [
                            BookingStatus.acceptedPaymentPending,
                            BookingStatus.paymentProcessing,
                            BookingStatus.confirmed,
                            BookingStatus.inProgress,
                            BookingStatus.completed,
                          ].contains(booking.status),
                        )
                        .toList();
                    if (riders.isEmpty) {
                      return Text(
                        'No riders yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }
                    return Column(
                      children: [
                        for (final booking in riders) ...[
                          _OwnerRiderRow(booking: booking),
                          const SizedBox(height: 9),
                        ],
                      ],
                    );
                  },
                ),
                if (ride.seatsAvailable > 0) ...[
                  const SizedBox(height: 8),
                  CustomPaint(
                    painter: _DashedRoundedBorderPainter(
                      color: const Color(0xFFC9C9CE),
                      radius: 10,
                    ),
                    child: SizedBox(
                      height: 46,
                      child: Center(
                        child: Text(
                          '${ride.seatsAvailable} ${ride.seatsAvailable == 1 ? 'seat' : 'seats'} open — share your ride link',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset + 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFE2DE),
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: ride.status == 'published'
                            ? AppHaptics.wrap(widget.onCancel)
                            : null,
                        child: const Text('Cancel ride'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.softSurface,
                          foregroundColor: AppColors.ink,
                        ),
                        onPressed: ride.shareUrl.isEmpty
                            ? null
                            : () => SharePlus.instance.share(
                                ShareParams(text: ride.shareUrl),
                              ),
                        child: const Text('Share link'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<SeatBooking>>(
                  future: _bookings,
                  builder: (context, snapshot) {
                    final completed = (snapshot.data ?? const <SeatBooking>[])
                        .where(
                          (booking) =>
                              {
                                BookingStatus.completed,
                                BookingStatus.payoutHeld,
                              }.contains(booking.status) &&
                              !booking.driverHasRated,
                        )
                        .toList(growable: false);
                    final confirmed = (snapshot.data ?? const <SeatBooking>[])
                        .where(
                          (booking) =>
                              booking.status == BookingStatus.confirmed,
                        )
                        .toList();
                    if (completed.isNotEmpty) {
                      return FilledButton(
                        onPressed: _openingRatings
                            ? null
                            : () => _rateRiders(completed),
                        child: Text(
                          _openingRatings ? 'Opening…' : 'Rate riders',
                        ),
                      );
                    }
                    return FilledButton(
                      onPressed: confirmed.isEmpty || _startingTrip
                          ? null
                          : _startTrip,
                      child: Text(
                        _startingTrip ? 'Optimizing route…' : 'Start trip',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startTrip() async {
    setState(() => _startingTrip = true);
    try {
      final plan = await ref
          .read(rideRepositoryProvider)
          .startLiveTrip(widget.ride.id);
      if (!mounted) return;
      showAppNotice(context, 'Trip started. Your optimized route is ready.');
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LiveTripScreen(
            ride: widget.ride.copyWith(status: 'in_progress'),
            isDriver: true,
            initialPlan: plan,
          ),
        ),
      );
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _startingTrip = false);
    }
  }

  Future<void> _rateRiders(List<SeatBooking> bookings) async {
    if (_openingRatings) return;
    setState(() => _openingRatings = true);
    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => RateRidersScreen(bookings: bookings)),
      );
      if (!mounted) return;
      setState(_reloadBookings);
    } finally {
      if (mounted) setState(() => _openingRatings = false);
    }
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _OwnerRiderRow extends ConsumerWidget {
  const _OwnerRiderRow({required this.booking});

  final SeatBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/profiles/${booking.riderId}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            RideAvatar(
              initials: booking.riderInitials,
              photoUrl: booking.riderPhotoUrl,
              radius: 16,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.riderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    switch (booking.status) {
                      BookingStatus.acceptedPaymentPending =>
                        'Accepted · payment pending',
                      BookingStatus.paymentProcessing =>
                        'Accepted · payment processing',
                      BookingStatus.inProgress =>
                        'Trip in progress · ${booking.seat.label}',
                      _ =>
                        '${booking.seat.label} · ${booking.pickupLocation?.displayName ?? 'Pickup code ready'}',
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Message rider',
              onPressed: () async {
                try {
                  final conversation = await ref
                      .read(messagingRepositoryProvider)
                      .openBookingConversation(booking.id);
                  if (context.mounted) {
                    context.push(
                      '/messages/${Uri.encodeComponent(conversation.id)}',
                    );
                  }
                } on AppFailure catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatDiagram extends StatelessWidget {
  const _SeatDiagram({
    required this.ride,
    required this.selectedSeat,
    required this.onSelected,
    this.interactive = true,
  });

  final Ride ride;
  final BookingSeat selectedSeat;
  final ValueChanged<BookingSeat> onSelected;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final seats = ['Front', 'Left', 'Right'];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const Text(
            'FRONT',
            style: TextStyle(
              color: AppColors.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: _Seat(label: 'Driver', taken: true)),
              const SizedBox(width: 10),
              Expanded(
                child: _Seat(
                  label: seats[0],
                  price: ride.priceLabel,
                  selected: selectedSeat == BookingSeat.front,
                  onTap: interactive
                      ? () => onSelected(BookingSeat.front)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'REAR',
            style: TextStyle(
              color: AppColors.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Seat(
                  label: seats[1],
                  price: ride.priceLabel,
                  selected: selectedSeat == BookingSeat.rearLeft,
                  onTap: interactive
                      ? () => onSelected(BookingSeat.rearLeft)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Seat(
                  label: seats[2],
                  price: ride.priceLabel,
                  selected: selectedSeat == BookingSeat.rearRight,
                  onTap: interactive
                      ? () => onSelected(BookingSeat.rearRight)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.label,
    this.price,
    this.taken = false,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String? price;
  final bool taken;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '$label seat',
      child: InkWell(
        onTap: onTap == null ? null : AppHaptics.wrap(onTap!),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: taken ? const Color(0xFFF0F0F0) : Colors.white,
            border: taken
                ? null
                : Border.all(
                    color: selected ? AppColors.ink : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: taken ? AppColors.mutedInk : AppColors.ink,
                ),
              ),
              if (taken)
                const Text(
                  'Taken',
                  style: TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (price != null)
                Text(price!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatRequestSheet extends StatefulWidget {
  const _SeatRequestSheet({required this.ride, required this.selectedSeat});

  final Ride ride;
  final BookingSeat selectedSeat;

  @override
  State<_SeatRequestSheet> createState() => _SeatRequestSheetState();
}

class _SeatRequestSheetState extends State<_SeatRequestSheet> {
  RidePlacePrediction? _pickup;
  RidePlacePrediction? _dropoff;

  Future<void> _choosePickup() async {
    final place = await showRidePlacePicker(
      context,
      title: 'Exact pickup address',
      rideId: widget.ride.id,
      initialQuery: _pickup?.displayName ?? widget.ride.origin.displayName,
    );
    if (place != null && mounted) setState(() => _pickup = place);
  }

  Future<void> _chooseDropoff() async {
    final place = await showRidePlacePicker(
      context,
      title: 'Exact drop-off address',
      rideId: widget.ride.id,
      initialQuery:
          _dropoff?.displayName ?? widget.ride.destination.displayName,
    );
    if (place != null && mounted) setState(() => _dropoff = place);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final ready = _pickup != null && _dropoff != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 10, 24, 18 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm your stops',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.selectedSeat.label} seat · Choose the exact addresses the driver will use.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _StopPickerButton(
            label: 'Pickup',
            value: _pickup?.displayName ?? 'Choose pickup address',
            onTap: _choosePickup,
          ),
          const SizedBox(height: 10),
          _StopPickerButton(
            label: 'Drop-off',
            value: _dropoff?.displayName ?? 'Choose drop-off address',
            onTap: _chooseDropoff,
          ),
          const SizedBox(height: 12),
          Text(
            'Both addresses must be within 1 mile of the driver’s route or inside the approved service boundary.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: ready
                ? () => Navigator.pop(
                    context,
                    SeatRequest(
                      rideId: widget.ride.id,
                      seat: widget.selectedSeat,
                      pickupPlaceId: _pickup!.placeId,
                      dropoffPlaceId: _dropoff!.placeId,
                    ),
                  )
                : null,
            child: const Text('Send request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }
}

class _StopPickerButton extends StatelessWidget {
  const _StopPickerButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
