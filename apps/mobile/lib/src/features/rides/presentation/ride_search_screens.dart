import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/place_picker_sheet.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/routing/app_router.dart';

class SearchRidesScreen extends StatefulWidget {
  const SearchRidesScreen({super.key});

  @override
  State<SearchRidesScreen> createState() => _SearchRidesScreenState();
}

class _SearchRidesScreenState extends State<SearchRidesScreen> {
  String _origin = 'UCSB / Isla Vista';
  String _destination = 'San Mateo / Peninsula';
  RidePlacePrediction? _originPlace;
  RidePlacePrediction? _destinationPlace;
  DateTime _date = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  DriverGenderFilter _gender = DriverGenderFilter.any;
  LuggageAllowance _luggage = LuggageAllowance.oneSuitcase;
  double _minimumRating = 0;
  bool _afternoonOnly = false;
  String? _error;

  Future<void> _pickOrigin() async {
    final place = await showRidePlacePicker(
      context,
      title: 'Pickup area',
      initialQuery: _origin,
    );
    if (place != null && mounted) {
      setState(() {
        _originPlace = place;
        _origin = place.displayName;
        _error = null;
      });
    }
  }

  Future<void> _pickDestination() async {
    final place = await showRidePlacePicker(
      context,
      title: 'Drop-off area',
      initialQuery: _destination,
    );
    if (place != null && mounted) {
      setState(() {
        _destinationPlace = place;
        _destination = place.displayName;
        _error = null;
      });
    }
  }

  Future<void> _pickLuggage() async {
    final value = await showModalBottomSheet<LuggageAllowance>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in LuggageAllowance.values)
              ListTile(
                title: Text(option.label),
                trailing: option == _luggage
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (value != null && mounted) setState(() => _luggage = value);
  }

  void _search() {
    if (_originPlace == null || _destinationPlace == null) {
      setState(
        () => _error = 'Choose both areas from Google Places to search.',
      );
      return;
    }
    final day = DateTime(_date.year, _date.month, _date.day);
    final start = _afternoonOnly ? day.add(const Duration(hours: 12)) : day;
    final end = _afternoonOnly
        ? day.add(const Duration(hours: 18))
        : day.add(const Duration(days: 1));
    final criteria = RideSearchCriteria(
      originQuery: _originPlace!.mainText,
      destinationQuery: _destinationPlace!.mainText,
      pickupPlaceId: _originPlace!.placeId,
      dropoffPlaceId: _destinationPlace!.placeId,
      startAt: start,
      endAt: end,
      driverGender: _gender,
      luggageRequired: _luggage,
      minimumRating: _minimumRating,
    );
    context.push(AppRoutes.searchResults, extra: criteria);
  }

  @override
  Widget build(BuildContext context) {
    return RidePageScaffold(
      role: PrimaryRole.rider,
      navigationIndex: 1,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                _CenteredHeader(title: 'Find a ride', onBack: context.pop),
                const SizedBox(height: 25),
                SizedBox(
                  height: 140,
                  child: RideRouteCard(
                    origin: _origin,
                    destination: _destination,
                    onOriginTap: _pickOrigin,
                    onDestinationTap: _pickDestination,
                  ),
                ),
                const SizedBox(height: 27),
                const _SectionLabel('When'),
                const SizedBox(height: 11),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(3, (index) {
                      final date = DateUtils.dateOnly(
                        DateTime.now().add(Duration(days: index + 1)),
                      );
                      return Padding(
                        padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                        child: RideChoiceChip(
                          label: formatShortDate(date),
                          selected: DateUtils.isSameDay(_date, date),
                          onTap: () => setState(() => _date = date),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionLabel('Ride with'),
                const SizedBox(height: 11),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final value in const [
                        DriverGenderFilter.any,
                        DriverGenderFilter.women,
                      ]) ...[
                        RideChoiceChip(
                          label: value.label,
                          selected: _gender == value,
                          onTap: () => setState(() => _gender = value),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionLabel('Filters'),
                const SizedBox(height: 11),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      RideChoiceChip(
                        label: _luggage.label,
                        selected: true,
                        onTap: _pickLuggage,
                      ),
                      const SizedBox(width: 8),
                      RideChoiceChip(
                        label: '4.8+ rating',
                        selected: _minimumRating == 4.8,
                        onTap: () => setState(
                          () =>
                              _minimumRating = _minimumRating == 4.8 ? 0 : 4.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      RideChoiceChip(
                        label: 'Afternoon',
                        selected: _afternoonOnly,
                        onTap: () =>
                            setState(() => _afternoonOnly = !_afternoonOnly),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.red),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
            child: FilledButton(
              onPressed: _search,
              child: const Text('Search rides'),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({required this.criteria, super.key});

  final RideSearchCriteria criteria;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late RideSearchCriteria _criteria;
  late Future<List<Ride>> _rides;
  int? _resultCount;

  @override
  void initState() {
    super.initState();
    _criteria = widget.criteria;
    _load();
  }

  void _load() {
    _resultCount = null;
    final request = ref.read(rideRepositoryProvider).searchRides(_criteria);
    _rides = request;
    request.then((rides) {
      if (!mounted || !identical(_rides, request)) return;
      setState(() => _resultCount = rides.length);
    }, onError: (_) {});
  }

  void _sort(RideSort sort) {
    setState(() {
      _criteria = _criteria.copyWith(sort: sort);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _CenteredHeader(
                title:
                    '${_criteria.originQuery} → ${_criteria.destinationQuery}',
                subtitle:
                    '${formatShortDate(_criteria.startAt)}${_resultCount == null ? '' : ' · $_resultCount ${_resultCount == 1 ? 'ride' : 'rides'}'}',
                onBack: context.pop,
              ),
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (final sort in RideSort.values) ...[
                    RideChoiceChip(
                      label: sort.label,
                      selected: _criteria.sort == sort,
                      onTap: () => _sort(sort),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Ride>>(
                future: _rides,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final message = snapshot.error is AppFailure
                        ? (snapshot.error! as AppFailure).message
                        : 'We could not load rides. Try again.';
                    return _ResultsMessage(
                      title: message,
                      action: 'Try again',
                      onTap: () => setState(_load),
                    );
                  }
                  final rides = snapshot.data ?? const [];
                  if (rides.isEmpty) {
                    return _ResultsMessage(
                      title: 'No rides match these filters.',
                      action: 'Change search',
                      onTap: context.pop,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    itemCount: rides.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => RideCard(
                      ride: rides[index],
                      selected: index == 1,
                      onTap: () => context.push('/rides/${rides[index].id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredHeader extends StatelessWidget {
  const _CenteredHeader({
    required this.title,
    required this.onBack,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: subtitle == null ? 42 : 55,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 32),
            ),
          ),
          Column(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _ResultsMessage extends StatelessWidget {
  const _ResultsMessage({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
