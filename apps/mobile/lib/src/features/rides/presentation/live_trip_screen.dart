import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
import 'package:sidecar/src/features/bookings/presentation/trip_rating_screen.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveTripScreen extends ConsumerStatefulWidget {
  const LiveTripScreen({
    required this.ride,
    required this.isDriver,
    this.initialPlan,
    this.riderBooking,
    super.key,
  });

  final Ride ride;
  final bool isDriver;
  final LiveTripPlan? initialPlan;
  final SeatBooking? riderBooking;

  @override
  ConsumerState<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends ConsumerState<LiveTripScreen>
    with WidgetsBindingObserver {
  LiveTripPlan? _plan;
  List<SeatBooking> _bookings = const [];
  bool _loading = true;
  bool _submitting = false;
  bool _ratingOpened = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _plan = widget.initialPlan;
    _refresh(showLoading: _plan == null);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(showLoading: false);
  }

  Future<void> _refresh({required bool showLoading}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final planFuture = ref
          .read(rideRepositoryProvider)
          .getLiveTrip(widget.ride.id);
      final bookingsFuture = widget.isDriver
          ? ref
                .read(bookingRepositoryProvider)
                .listRideRequests(rideId: widget.ride.id, forceRefresh: true)
          : Future.value(<SeatBooking>[
              if (widget.riderBooking != null) widget.riderBooking!,
            ]);
      final results = await Future.wait<Object>([planFuture, bookingsFuture]);
      if (!mounted) return;
      setState(() {
        _plan = results[0] as LiveTripPlan;
        _bookings = results[1] as List<SeatBooking>;
        _loading = false;
      });
      _openRatingWhenComplete(_plan!);
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_plan == null) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _loading && plan == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _refresh(showLoading: false),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        children: [
                          _Header(ride: widget.ride),
                          const SizedBox(height: 24),
                          if (plan != null) ...[
                            _PhaseCard(plan: plan),
                            const SizedBox(height: 24),
                            _StopSection(
                              title: 'Pickup order',
                              subtitle:
                                  'Optimized from the driver’s departure point',
                              stops: plan.pickupStops,
                              active: plan.phase == LiveTripPhase.pickups,
                              openNavigation: widget.isDriver,
                            ),
                            const SizedBox(height: 24),
                            if (!widget.isDriver ||
                                plan.phase != LiveTripPhase.pickups)
                              _StopSection(
                                title: 'Drop-off order',
                                subtitle: 'Optimized for the remaining route',
                                stops: plan.dropoffStops,
                                active: plan.phase != LiveTripPhase.pickups,
                                openNavigation: widget.isDriver,
                              )
                            else
                              const _DropoffPendingCard(),
                          ],
                        ],
                      ),
                    ),
            ),
            if (plan != null)
              _BottomActions(
                isDriver: widget.isDriver,
                submitting: _submitting,
                hasWaitingRiders: _waitingBookings.isNotEmpty,
                phase: plan.phase,
                riderBooking: widget.riderBooking,
                onPickupCode: _showPickupCodeSheet,
                onCompleteTrip: _completeTrip,
                onRateTrip: _openRating,
              ),
          ],
        ),
      ),
    );
  }

  List<SeatBooking> get _waitingBookings => _bookings
      .where((booking) => booking.status == BookingStatus.confirmed)
      .toList(growable: false);

  Future<void> _showPickupCodeSheet() async {
    final bookings = _waitingBookings;
    if (bookings.isEmpty) return;
    final controller = TextEditingController();
    SeatBooking selected = bookings.first;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Confirm rider pickup',
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Select the rider you have arrived for, then enter their 4-digit pickup code.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<SeatBooking>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Rider'),
                items: [
                  for (final booking in bookings)
                    DropdownMenuItem(
                      value: booking,
                      child: Text(booking.riderName),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setSheetState(() => selected = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Pickup code'),
              ),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        try {
                          await ref
                              .read(bookingRepositoryProvider)
                              .verifyPickupCode(selected.id, controller.text);
                          if (!mounted) return;
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          showAppNotice(
                            context,
                            '${selected.riderName} is checked in.',
                          );
                          await _refresh(showLoading: false);
                        } on AppFailure catch (error) {
                          if (sheetContext.mounted) {
                            showAppNotice(
                              sheetContext,
                              error.message,
                              kind: AppNoticeKind.error,
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      },
                child: const Text('Confirm pickup'),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _completeTrip() async {
    if (_submitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete this ride?'),
        content: const Text(
          'This ends the live trip, completes every rider’s booking, and releases eligible payouts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ride complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .completeDriverTrip(widget.ride.id);
      if (!mounted) return;
      ref.read(rideRepositoryProvider).invalidateRide(widget.ride.id);
      showAppNotice(context, 'Ride completed. Riders can now rate the trip.');
      Navigator.pop(context, true);
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openRatingWhenComplete(LiveTripPlan plan) {
    if (widget.isDriver ||
        plan.phase != LiveTripPhase.complete ||
        _ratingOpened ||
        widget.riderBooking == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRating());
  }

  Future<void> _openRating() async {
    final booking = widget.riderBooking;
    if (!mounted || booking == null || _ratingOpened) return;
    _ratingOpened = true;
    final rated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TripRatingScreen(booking: booking)),
    );
    if (!mounted) return;
    if (rated == true) {
      Navigator.pop(context, true);
    } else {
      _ratingOpened = false;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: ride.vehicle.makeAndModel.isEmpty ? 74 : 92,
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
            Text('Live trip', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 3),
            Text(
              '${ride.origin.displayName} → ${ride.destination.displayName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (ride.vehicle.makeAndModel.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                ride.vehicle.makeAndModel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.plan});

  final LiveTripPlan plan;

  @override
  Widget build(BuildContext context) {
    final pickupsDone = plan.pickupStops
        .where((stop) => stop.completedAt != null)
        .length;
    final (title, detail) = switch (plan.phase) {
      LiveTripPhase.pickups => (
        'Picking up riders',
        '$pickupsDone of ${plan.pickupStops.length} picked up',
      ),
      LiveTripPhase.dropoffs => (
        'All riders are on board',
        'Continue with the optimized drop-off order',
      ),
      LiveTripPhase.complete => ('Trip complete', 'All stops are complete'),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.route_outlined, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const _LiveBadge(),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Text(
      'LIVE',
      style: TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}

class _DropoffPendingCard extends StatelessWidget {
  const _DropoffPendingCard();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.softSurface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Drop-off order', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'The remaining route will be optimized after every rider is picked up.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _StopSection extends StatelessWidget {
  const _StopSection({
    required this.title,
    required this.subtitle,
    required this.stops,
    required this.active,
    required this.openNavigation,
  });

  final String title;
  final String subtitle;
  final List<LiveTripStop> stops;
  final bool active;
  final bool openNavigation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 3),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: active ? AppColors.softSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E2E2)),
        ),
        child: Column(
          children: [
            for (var index = 0; index < stops.length; index++) ...[
              _StopRow(
                stop: stops[index],
                number: index + 1,
                openNavigation: openNavigation,
              ),
              if (index != stops.length - 1)
                const Divider(height: 1, indent: 54, endIndent: 14),
            ],
          ],
        ),
      ),
    ],
  );
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.number,
    required this.openNavigation,
  });

  final LiveTripStop stop;
  final int number;
  final bool openNavigation;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: openNavigation
        ? () => _openNavigation(context, stop.location)
        : null,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: stop.completedAt != null ? AppColors.ink : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink),
            ),
            child: stop.completedAt != null
                ? const Icon(Icons.check, color: Colors.white, size: 17)
                : Text('$number'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        stop.riderName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (stop.eta != null)
                      Text(
                        'ETA ${_formatEta(stop.eta!)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  stop.location.formattedAddress,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (openNavigation) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Open directions',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ],
            ),
          ),
          if (openNavigation) const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.isDriver,
    required this.submitting,
    required this.hasWaitingRiders,
    required this.phase,
    required this.riderBooking,
    required this.onPickupCode,
    required this.onCompleteTrip,
    required this.onRateTrip,
  });

  final bool isDriver;
  final bool submitting;
  final bool hasWaitingRiders;
  final LiveTripPhase phase;
  final SeatBooking? riderBooking;
  final VoidCallback onPickupCode;
  final VoidCallback onCompleteTrip;
  final VoidCallback onRateTrip;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.softSurface)),
      ),
      child: isDriver
          ? FilledButton(
              onPressed: submitting
                  ? null
                  : hasWaitingRiders
                  ? onPickupCode
                  : phase != LiveTripPhase.complete
                  ? onCompleteTrip
                  : null,
              child: Text(
                submitting
                    ? 'Completing…'
                    : hasWaitingRiders
                    ? 'Enter rider pickup code'
                    : phase != LiveTripPhase.complete
                    ? 'Ride complete'
                    : 'Trip complete',
              ),
            )
          : FilledButton(
              onPressed: phase == LiveTripPhase.complete
                  ? onRateTrip
                  : riderBooking?.status == BookingStatus.confirmed
                  ? () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            PickupCodeScreen(booking: riderBooking!),
                      ),
                    )
                  : null,
              child: Text(
                phase == LiveTripPhase.complete
                    ? 'Rate driver and trip'
                    : riderBooking?.status == BookingStatus.confirmed
                    ? 'View my pickup code'
                    : 'Pickup confirmed',
              ),
            ),
    );
  }
}

String _formatEta(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

Future<void> _openNavigation(BuildContext context, RideLocation stop) async {
  final coordinate = '${stop.latitude},${stop.longitude}';
  final Uri primary;
  if (Platform.isIOS) {
    primary = Uri.https('maps.apple.com', '/', {
      'daddr': coordinate,
      'dirflg': 'd',
    });
  } else {
    primary = Uri.parse(
      'geo:0,0?q=${Uri.encodeComponent('$coordinate (${stop.formattedAddress})')}',
    );
  }
  var opened = await launchUrl(primary, mode: LaunchMode.externalApplication);
  if (!opened) {
    opened = await launchUrl(
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': coordinate,
        'travelmode': 'driving',
      }),
      mode: LaunchMode.externalApplication,
    );
  }
  if (!opened && context.mounted) {
    showAppNotice(
      context,
      'Navigation could not be opened.',
      kind: AppNoticeKind.error,
    );
  }
}
