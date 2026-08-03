import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class RideDetailsScreen extends ConsumerStatefulWidget {
  const RideDetailsScreen({required this.rideId, super.key});

  final String rideId;

  @override
  ConsumerState<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends ConsumerState<RideDetailsScreen> {
  late Future<Ride> _ride;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _ride = ref.read(rideRepositoryProvider).getRide(widget.rideId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Ride>(
          future: _ride,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              final message = snapshot.error is AppFailure
                  ? (snapshot.error! as AppFailure).message
                  : 'That ride is no longer available.';
              return Center(
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
              );
            }
            return _RideDetails(ride: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _RideDetails extends StatelessWidget {
  const _RideDetails({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  RideMapPreview(encodedPolyline: ride.encodedPolyline),
                  Positioned(
                    left: 18,
                    top: 12,
                    child: IconButton.filledTonal(
                      tooltip: 'Back',
                      onPressed: context.pop,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        RideAvatar(initials: ride.driverInitials),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ride.driverName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '★ ${ride.driverRating == 0 ? 'New' : ride.driverRating.toStringAsFixed(1)} · ${ride.driverTrips} trips · ${ride.vehicle.year}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const RideBadge(label: 'Verified', checked: true),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 112,
                      child: RideRouteCard(
                        origin: ride.origin.displayName,
                        destination: ride.destination.displayName,
                        originSubtitle:
                            '${formatShortDate(ride.departureAt)} · ${formatTime(ride.departureAt)}',
                        destinationSubtitle:
                            'ETA ${formatTime(ride.departureAt.add(Duration(seconds: ride.durationSeconds)))}',
                      ),
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
                        Text(
                          'Same price, any seat',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    _SeatDiagram(ride: ride),
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
          padding: const EdgeInsets.fromLTRB(24, 13, 24, 18),
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
                      '${ride.priceLabel} / seat',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(
                      'Front seat · ${ride.seatsAvailable} of ${ride.seatsTotal} left',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: Semantics(
                  button: true,
                  enabled: false,
                  label: 'Request seat',
                  child: IgnorePointer(
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Request seat'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeatDiagram extends StatelessWidget {
  const _SeatDiagram({required this.ride});

  final Ride ride;

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
            style: TextStyle(color: AppColors.mutedInk, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: _Seat(label: 'Driver', taken: true)),
              const SizedBox(width: 10),
              Expanded(
                child: _Seat(label: seats[0], price: ride.priceLabel),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'REAR',
            style: TextStyle(color: AppColors.mutedInk, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Seat(label: seats[1], price: ride.priceLabel),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Seat(label: seats[2], price: ride.priceLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({required this.label, this.price, this.taken = false});

  final String label;
  final String? price;
  final bool taken;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: taken ? const Color(0xFFF0F0F0) : Colors.white,
        border: taken ? null : Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: taken ? AppColors.mutedInk : AppColors.ink),
          ),
          if (taken)
            const Text(
              'Taken',
              style: TextStyle(color: AppColors.mutedInk, fontSize: 11),
            )
          else if (price != null)
            Text(price!, style: Theme.of(context).textTheme.bodySmall),
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
