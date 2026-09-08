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
import 'package:sidecar/src/features/profile/presentation/account_support_screens.dart';
import 'package:sidecar/src/theme/app_theme.dart';

String _rideShareText(Ride ride) => [
  'SideCar trip',
  '${ride.origin.displayName} → ${ride.destination.displayName}',
  '${formatShortDate(ride.departureAt)} at ${formatTime(ride.departureAt)}',
  '${ride.priceLabel} per seat · ${ride.seatsAvailable} seats available',
  'Luggage: ${ride.luggageAllowance.label}',
  'Rider preference: ${ride.genderRestriction.label}',
  if (ride.vehicle.makeAndModel.isNotEmpty)
    'Vehicle: ${ride.vehicle.makeAndModel}',
  ride.shareUrl,
].join('\n');

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
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CancelRideConfirmationScreen(ride: ride),
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
                    encodedPolyline: ride.encodedPolyline,
                    origin: ride.origin,
                    destination: ride.destination,
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
                    RideSummaryCard(
                      origin: ride.origin.displayName,
                      destination: ride.destination.displayName,
                      dateLabel: formatShortDate(ride.departureAt),
                      timeLabel: formatTime(ride.departureAt),
                      priceLabel: ride.priceLabel,
                      bookedLabel:
                          '${ride.bookedSeats}/${ride.seatsTotal} booked',
                      keyPrefix: 'rider-detail-${ride.id}',
                    ),
                    const SizedBox(height: 24),
                    if (booking != null) ...[
                      _BookedTripDetails(booking: booking!),
                      const SizedBox(height: 22),
                    ],
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
                    const SizedBox(height: 18),
                    _DetailValue(
                      label: 'Vehicle',
                      value: ride.vehicle.makeAndModel.isEmpty
                          ? 'Not provided'
                          : ride.vehicle.makeAndModel,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pick your seat',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
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

String _bookedTripTitle(SeatBooking booking) {
  if (booking.riderNoShow) return 'Marked as no-show';
  return switch (booking.status) {
    BookingStatus.inProgress => 'Trip in progress',
    BookingStatus.completed => 'Trip complete',
    BookingStatus.payoutHeld => 'Trip complete',
    _ => 'Your ride',
  };
}

String _bookedTripStatus(SeatBooking booking) {
  if (booking.riderNoShow) return 'No-show';
  return switch (booking.status) {
    BookingStatus.inProgress => 'In progress',
    BookingStatus.completed => 'Completed',
    BookingStatus.payoutHeld => 'Completed',
    _ => 'Confirmed',
  };
}

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
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
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
    return SafeArea(
      child: FutureBuilder<List<SeatBooking>>(
        future: _bookings,
        builder: (context, snapshot) {
          final bookings = snapshot.data ?? const <SeatBooking>[];
          final riders = bookings
              .where(
                (booking) => const {
                  BookingStatus.acceptedPaymentPending,
                  BookingStatus.paymentProcessing,
                  BookingStatus.confirmed,
                  BookingStatus.inProgress,
                  BookingStatus.completed,
                }.contains(booking.status),
              )
              .toList(growable: false);
          final completed = bookings
              .where(
                (booking) =>
                    const {
                      BookingStatus.completed,
                      BookingStatus.payoutHeld,
                    }.contains(booking.status) &&
                    !booking.driverHasRated,
              )
              .toList(growable: false);
          final confirmed = bookings
              .where((booking) => booking.status == BookingStatus.confirmed)
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 7, 24, 0),
                child: SizedBox(
                  height: 30,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 24,
                            height: 30,
                          ),
                          onPressed: context.pop,
                          icon: const FinalDraftBackIcon(size: 30),
                        ),
                      ),
                      Text(
                        'Your ride',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 157,
                child: RideMapPreview(
                  mapPreviewUrl: ride.mapPreviewUrl,
                  encodedPolyline: ride.encodedPolyline,
                  origin: ride.origin,
                  destination: ride.destination,
                  showZoomControls: false,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _OwnerRideSummaryCard(ride: ride),
              ),
              const SizedBox(height: 23),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: _OwnerDetailLabel(
                        'Luggage per rider',
                        ride.luggageAllowance.label,
                      ),
                    ),
                    Expanded(
                      child: _OwnerDetailLabel(
                        'Rider preference',
                        ride.genderRestriction.label,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: _OwnerDetailLabel(
                  'Vehicle',
                  ride.vehicle.makeAndModel.isEmpty
                      ? 'Not provided'
                      : ride.vehicle.makeAndModel,
                ),
              ),
              const SizedBox(height: 38),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Your riders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: snapshot.connectionState != ConnectionState.done
                    ? const SizedBox(
                        height: 63,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : riders.isEmpty
                    ? Container(
                        height: 63,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No riders yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : Column(
                        children: [
                          for (final booking in riders) ...[
                            _OwnerRiderRow(booking: booking),
                            if (booking != riders.last)
                              const SizedBox(height: 9),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.dangerSurface,
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
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: _rideShareText(ride)),
                        ),
                        child: const Text('Share link'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: completed.isNotEmpty
                    ? FilledButton(
                        style: AppButtonStyles.primaryFilled,
                        onPressed: _openingRatings
                            ? null
                            : () => _rateRiders(completed),
                        child: Text(
                          _openingRatings ? 'Opening…' : 'Rate riders',
                        ),
                      )
                    : FilledButton(
                        style: AppButtonStyles.primaryFilled,
                        onPressed: confirmed.isEmpty || _startingTrip
                            ? null
                            : _startTrip,
                        child: Text(
                          _startingTrip ? 'Optimizing route…' : 'Start trip',
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.information,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Drivers must carry active auto insurance, wait at least 10 minutes after the agreed pickup time before marking a rider as a no-show, and understand that a 5% platform fee is deducted from each reimbursement.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Start trip when you're ready to head out!\n"
                "We'll automatically order your stops for the fastest route.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          );
        },
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

class _OwnerRideSummaryCard extends StatelessWidget {
  const _OwnerRideSummaryCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) => RideSummaryCard(
    origin: ride.origin.displayName,
    destination: ride.destination.displayName,
    dateLabel: formatShortDate(ride.departureAt),
    timeLabel: formatTime(ride.departureAt),
    priceLabel: ride.priceLabel,
    bookedLabel: '${ride.bookedSeats}/${ride.seatsTotal} booked',
    keyPrefix: 'owner-ride-${ride.id}',
  );
}

class _OwnerDetailLabel extends StatelessWidget {
  const _OwnerDetailLabel(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.secondaryInk,
          fontSize: 13,
        ),
      ),
      if (value != null) ...[
        const SizedBox(height: 5),
        Text(
          value!,
          softWrap: true,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ],
  );
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
                    softWrap: true,
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
                        'Pick up: ${booking.pickupLocation?.formattedAddress ?? booking.pickupLocation?.displayName ?? 'Pickup code ready'}',
                    },
                    softWrap: true,
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
              icon: const FinalDraftIcon(
                kind: FinalDraftIconKind.messages,
                selected: false,
                color: AppColors.ink,
                size: 22,
              ),
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
                    color: selected ? AppColors.primary : AppColors.border,
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
            'Both addresses must be within 1 mile of the driver’s route or student housing (Isla Vista / UCSB housing).',
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
            softWrap: true,
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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryInk,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            softWrap: true,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 13, height: 1.25),
          ),
        ],
      ),
    );
  }
}
