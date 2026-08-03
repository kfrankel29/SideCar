import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
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
  PrimaryRole? _loadedRole;

  void _ensureLoad(PrimaryRole role) {
    if (_rides != null && _loadedRole == role) return;
    _loadedRole = role;
    final repository = ref.read(rideRepositoryProvider);
    _rides = role == PrimaryRole.driver
        ? repository.listMyRides()
        : repository.listLeavingSoon();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final role = profile?.primaryRole ?? PrimaryRole.rider;
    _ensureLoad(role);
    return RidePageScaffold(
      role: role,
      navigationIndex: 0,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _rides = null);
          _ensureLoad(role);
          await _rides;
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
                RideAvatar(initials: _initials(profile), radius: 22),
              ],
            ),
            const SizedBox(height: 18),
            if (role == PrimaryRole.driver)
              _DriverHome(
                rides: _rides!,
                onRetry: () => setState(() => _rides = null),
              )
            else
              _RiderHome(
                rides: _rides!,
                onRetry: () => setState(() => _rides = null),
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
  const _RiderHome({required this.rides, required this.onRetry});

  final Future<List<Ride>> rides;
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
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              RideChoiceChip(
                label: 'Home for break',
                selected: true,
                compact: true,
                onTap: () => context.go(AppRoutes.searchRides),
              ),
              const SizedBox(width: 8),
              RideChoiceChip(
                label: 'This weekend',
                selected: false,
                compact: true,
                onTap: () => context.go(AppRoutes.searchRides),
              ),
              const SizedBox(width: 8),
              RideChoiceChip(
                label: 'Women only',
                selected: false,
                compact: true,
                onTap: () => context.go(AppRoutes.searchRides),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Leaving soon',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Search rides',
              onPressed: () => context.go(AppRoutes.searchRides),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
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
                .where((ride) => !ride.departureAt.isBefore(now))
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
  const _DriverHome({required this.rides, required this.onRetry});

  final Future<List<Ride>> rides;
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post your next ride',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Fill 3 seats = \$150 for a drive you're making",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBEBEBE),
                        ),
                      ),
                    ],
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
              child: _StatCard(value: '\$0', label: 'Earned this qtr'),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _StatCard(value: '— · 0', label: 'Rating · trips'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          'Your upcoming ride',
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
                .where((ride) => !ride.departureAt.isBefore(now))
                .toList();
            if (values.isEmpty) {
              return const _EmptyRides(
                title: 'No upcoming rides',
                message: 'Post a ride when you know your next trip.',
              );
            }
            final ride = values.first;
            return InkWell(
              onTap: () => context.push('/rides/${ride.id}'),
              child: Container(
                height: 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RideRouteCard(
                  origin: ride.origin.displayName,
                  destination: ride.destination.displayName,
                  originSubtitle:
                      '${formatShortDate(ride.departureAt)} · ${formatTime(ride.departureAt)}',
                  destinationSubtitle: 'Upcoming',
                ),
              ),
            );
          },
        ),
      ],
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
