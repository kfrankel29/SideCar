import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/place_picker_sheet.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class PostRideScreen extends ConsumerStatefulWidget {
  const PostRideScreen({super.key});

  @override
  ConsumerState<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends ConsumerState<PostRideScreen> {
  final _price = TextEditingController(text: '50');
  RidePlacePrediction? _origin;
  RidePlacePrediction? _destination;
  DateTime _date = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  TimeOfDay _time = const TimeOfDay(hour: 15, minute: 0);
  int _seats = 3;
  LuggageAllowance _luggage = LuggageAllowance.oneSuitcase;
  RideGenderRestriction _restriction = RideGenderRestriction.any;
  bool _repeatWeekly = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickPlace(bool origin) async {
    final current = origin ? _origin : _destination;
    final result = await showRidePlacePicker(
      context,
      title: origin ? 'Where are you leaving from?' : 'Where are you going?',
      initialQuery: current?.displayName ?? '',
    );
    if (result != null && mounted) {
      setState(() {
        if (origin) {
          _origin = result;
        } else {
          _destination = result;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null && mounted) {
      setState(() => _date = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(context: context, initialTime: _time);
    if (result != null && mounted) setState(() => _time = result);
  }

  Future<void> _submit() async {
    final priceDollars = int.tryParse(_price.text.trim());
    if (_origin == null || _destination == null) {
      setState(() => _error = 'Choose both places from the search results.');
      return;
    }
    if (priceDollars == null || priceDollars < 1) {
      setState(() => _error = 'Enter a valid price per seat.');
      return;
    }
    final departure = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(rideRepositoryProvider)
          .createRide(
            RideDraft(
              origin: _origin!,
              destination: _destination!,
              departureAt: departure,
              seats: _seats,
              pricePerSeatCents: priceDollars * 100,
              luggageAllowance: _luggage,
              genderRestriction: _restriction,
              repeatWeekly: _repeatWeekly,
            ),
          );
      if (mounted) context.go(AppRoutes.myRides);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'We could not post this ride. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnings = (int.tryParse(_price.text) ?? 0) * _seats;
    return RidePageScaffold(
      role: PrimaryRole.driver,
      navigationIndex: 1,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              children: [
                _PageHeader(title: 'Post a ride', onBack: context.pop),
                const SizedBox(height: 22),
                SizedBox(
                  height: 122,
                  child: RideRouteCard(
                    origin: _origin?.displayName ?? 'Choose origin',
                    destination:
                        _destination?.displayName ?? 'Choose destination',
                    onOriginTap: () => _pickPlace(true),
                    onDestinationTap: () => _pickPlace(false),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _TapField(
                        label: 'Date',
                        value: formatShortDate(_date),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TapField(
                        label: 'Time',
                        value: _time.format(context),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label('Seats'),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(3, (index) {
                              final seats = index + 1;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: RideChoiceChip(
                                  label: '$seats',
                                  selected: _seats == seats,
                                  compact: true,
                                  onTap: () => setState(() => _seats = seats),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label('Price / seat'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _price,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            decoration: const InputDecoration(
                              prefixText: '\$ ',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _Label('Luggage per rider'),
                const SizedBox(height: 9),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final value in LuggageAllowance.values) ...[
                        RideChoiceChip(
                          label: value.label,
                          selected: _luggage == value,
                          compact: true,
                          onTap: () => setState(() => _luggage = value),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _RestrictionSwitch(
                  title: 'Repeat weekly',
                  subtitle: 'Auto-post every ${formatWeekday(_date)}',
                  value: _repeatWeekly,
                  onChanged: (enabled) =>
                      setState(() => _repeatWeekly = enabled),
                ),
                const Divider(height: 1),
                _RestrictionSwitch(
                  title: 'Women riders only',
                  subtitle: 'Only women can request a seat',
                  value: _restriction == RideGenderRestriction.womenOnly,
                  onChanged: (enabled) => setState(
                    () => _restriction = enabled
                        ? RideGenderRestriction.womenOnly
                        : RideGenderRestriction.any,
                  ),
                ),
                const Divider(height: 1),
                _RestrictionSwitch(
                  title: 'Men riders only',
                  subtitle: 'Only men can request a seat',
                  value: _restriction == RideGenderRestriction.menOnly,
                  onChanged: (enabled) => setState(
                    () => _restriction = enabled
                        ? RideGenderRestriction.menOnly
                        : RideGenderRestriction.any,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                _saving ? 'Posting…' : 'Post ride · earn ~\$$earnings',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyRidesScreen extends ConsumerStatefulWidget {
  const MyRidesScreen({super.key});

  @override
  ConsumerState<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends ConsumerState<MyRidesScreen> {
  late Future<List<Ride>> _rides;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _rides = ref.read(rideRepositoryProvider).listMyRides();

  @override
  Widget build(BuildContext context) {
    return RidePageScaffold(
      role: PrimaryRole.driver,
      navigationIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'My rides',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Post a ride',
                  onPressed: () => context.go(AppRoutes.postRide),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.softSurface,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                children: [
                  for (final entry in const [
                    (0, 'Upcoming'),
                    (1, 'Recurring'),
                    (2, 'Past'),
                  ])
                    Expanded(
                      child: _RideListTab(
                        label: entry.$2,
                        selected: _selectedTab == entry.$1,
                        onTap: () => setState(() => _selectedTab = entry.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: FutureBuilder<List<Ride>>(
              future: _rides,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(_load),
                      child: const Text('Could not load rides · Try again'),
                    ),
                  );
                }
                final allRides = snapshot.data ?? const [];
                final now = DateTime.now();
                final rides = switch (_selectedTab) {
                  0 =>
                    allRides
                        .where((ride) => !ride.departureAt.isBefore(now))
                        .toList(),
                  1 =>
                    allRides
                        .where(
                          (ride) =>
                              ride.repeatWeekly &&
                              !ride.departureAt.isBefore(now),
                        )
                        .toList(),
                  _ =>
                    allRides
                        .where((ride) => ride.departureAt.isBefore(now))
                        .toList()
                      ..sort(
                        (left, right) =>
                            right.departureAt.compareTo(left.departureAt),
                      ),
                };
                if (rides.isEmpty) {
                  return Center(
                    child: Text(switch (_selectedTab) {
                      1 => 'No recurring rides.',
                      2 => 'No past rides.',
                      _ => 'No upcoming rides.',
                    }),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: rides.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _ManagedRideCard(ride: rides[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RideListTab extends StatelessWidget {
  const _RideListTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        height: 35,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? Colors.white : AppColors.mutedInk,
          ),
        ),
      ),
    );
  }
}

class _ManagedRideCard extends StatelessWidget {
  const _ManagedRideCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatShortDate(ride.departureAt)} · ${formatTime(ride.departureAt)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              RideBadge(
                label:
                    '${ride.seatsTotal - ride.seatsAvailable}/${ride.seatsTotal} booked',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: RideRouteCard(
              origin: ride.origin.displayName,
              destination: ride.destination.displayName,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/rides/${ride.id}'),
                  child: const Text('View'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: ride.shareUrl.isEmpty
                      ? null
                      : () => SharePlus.instance.share(
                          ShareParams(
                            text:
                                '${routeName(ride)}\n${formatShortDate(ride.departureAt)} · ${formatTime(ride.departureAt)}\n${ride.shareUrl}',
                          ),
                        ),
                  child: const Text('Share link'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 31),
            ),
          ),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  const _TapField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(value),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelMedium);
}

class _RestrictionSwitch extends StatelessWidget {
  const _RestrictionSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.ink,
          ),
        ],
      ),
    );
  }
}
