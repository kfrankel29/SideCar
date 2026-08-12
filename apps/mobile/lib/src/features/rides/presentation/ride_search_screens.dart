import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/place_picker_sheet.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class SearchRidesScreen extends StatefulWidget {
  const SearchRidesScreen({super.key});

  @override
  State<SearchRidesScreen> createState() => _SearchRidesScreenState();
}

class LeavingSoonScreen extends ConsumerStatefulWidget {
  const LeavingSoonScreen({super.key});

  @override
  ConsumerState<LeavingSoonScreen> createState() => _LeavingSoonScreenState();
}

class _LeavingSoonScreenState extends ConsumerState<LeavingSoonScreen> {
  late Future<List<Ride>> _rides;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool forceRefresh = false}) {
    _rides = ref
        .read(rideRepositoryProvider)
        .listLeavingSoon(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    final request = ref
        .read(rideRepositoryProvider)
        .listLeavingSoon(forceRefresh: true);
    setState(() => _rides = request);
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 15, 24, 12),
              child: _CenteredHeader(
                title: 'Leaving soon',
                subtitle: 'All available rides',
                onBack: context.pop,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Ride>>(
                  future: _rides,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _RefreshableResultsMessage(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return _RefreshableResultsMessage(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _load(forceRefresh: true)),
                          child: const Text('Could not load rides · Try again'),
                        ),
                      );
                    }
                    final rides = snapshot.data ?? const <Ride>[];
                    if (rides.isEmpty) {
                      return const _RefreshableResultsMessage(
                        child: Text('No rides are leaving soon.'),
                      );
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      itemCount: rides.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => RideCard(
                        ride: rides[index],
                        onTap: () => context.push('/rides/${rides[index].id}'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshableResultsMessage extends StatelessWidget {
  const _RefreshableResultsMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
    );
  }
}

class _SearchRidesScreenState extends State<SearchRidesScreen> {
  String _origin = '';
  String _destination = '';
  RidePlacePrediction? _originPlace;
  RidePlacePrediction? _destinationPlace;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _womenOnly = false;
  LuggageAllowance? _luggage;
  String? _language;
  double _minimumRating = 0;
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

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  Future<void> _pickLuggage() async {
    if (_luggage != null) {
      setState(() => _luggage = null);
      return;
    }
    final value = await showModalBottomSheet<LuggageAllowance>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final allowance in LuggageAllowance.values)
              ListTile(
                title: Text(allowance.label),
                onTap: () => Navigator.pop(context, allowance),
              ),
          ],
        ),
      ),
    );
    if (value != null && mounted) setState(() => _luggage = value);
  }

  Future<void> _pickLanguage() async {
    if (_language != null) {
      setState(() => _language = null);
      return;
    }
    final value = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: ListView(
            children: [
              for (final language in supportedSpokenLanguages)
                ListTile(
                  title: Text(language),
                  onTap: () => Navigator.pop(context, language),
                ),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) setState(() => _language = value);
  }

  void _search() {
    if (_originPlace == null || _destinationPlace == null) {
      setState(
        () => _error = 'Choose both areas from Google Places to search.',
      );
      return;
    }
    final day = DateTime(_date.year, _date.month, _date.day);
    final start = day;
    final end = day.add(const Duration(days: 1));
    final criteria = RideSearchCriteria(
      originQuery: _originPlace!.mainText,
      destinationQuery: _destinationPlace!.mainText,
      pickupPlaceId: _originPlace!.placeId,
      dropoffPlaceId: _destinationPlace!.placeId,
      startAt: start,
      endAt: end,
      driverGender: _womenOnly
          ? DriverGenderFilter.women
          : DriverGenderFilter.any,
      driverLanguage: _language ?? '',
      luggageRequired: _luggage ?? LuggageAllowance.backpack,
      minimumRating: _minimumRating,
    );
    context.push(AppRoutes.searchResults, extra: criteria);
  }

  @override
  Widget build(BuildContext context) {
    return RidePageScaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              children: [
                _CenteredHeader(
                  title: 'Find a ride',
                  onBack: () => context.go(AppRoutes.home),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  height: 140,
                  child: RideRouteCard(
                    origin: _origin,
                    destination: _destination,
                    originPlaceholder: 'Pick Up Location',
                    destinationPlaceholder: 'Drop Off Location',
                    onOriginTap: _pickOrigin,
                    onDestinationTap: _pickDestination,
                  ),
                ),
                const SizedBox(height: 27),
                const _SectionLabel('When'),
                const SizedBox(height: 11),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(formatShortDate(_date)),
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionLabel('Ride with'),
                const SizedBox(height: 11),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Women only',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Show rides offered by women drivers',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _womenOnly,
                        onChanged: (value) =>
                            setState(() => _womenOnly = value),
                      ),
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
                        label: 'Luggage',
                        selected: _luggage != null,
                        onTap: _pickLuggage,
                      ),
                      const SizedBox(width: 8),
                      RideChoiceChip(
                        label: 'Language',
                        selected: _language != null,
                        onTap: _pickLanguage,
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
  bool _showingClosest = false;

  @override
  void initState() {
    super.initState();
    _criteria = widget.criteria;
    _load();
  }

  void _load() {
    _resultCount = null;
    _showingClosest = false;
    final request = ref.read(rideRepositoryProvider).searchRides(_criteria);
    _rides = request;
    request.then((rides) {
      if (!mounted || !identical(_rides, request)) return;
      final hasExactDate = rides.any(
        (ride) =>
            !ride.departureAt.isBefore(_criteria.startAt) &&
            ride.departureAt.isBefore(_criteria.endAt),
      );
      setState(() {
        _resultCount = rides.length;
        _showingClosest = rides.isNotEmpty && !hasExactDate;
      });
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 15, 24, 0),
              child: _CenteredHeader(
                title:
                    '${_criteria.originQuery} → ${_criteria.destinationQuery}',
                subtitle:
                    '${_showingClosest ? 'Closest available' : formatShortDate(_criteria.startAt)}${_resultCount == null ? '' : ' · $_resultCount ${_resultCount == 1 ? 'ride' : 'rides'}'}',
                onBack: context.pop,
              ),
            ),
            const SizedBox(height: 14),
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
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: subtitle == null ? 42 : 55,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                onPressed: onBack,
                icon: const FinalDraftBackIcon(size: 24),
              ),
            ),
          Positioned.fill(
            left: onBack == null ? 0 : 38,
            right: onBack == null ? 0 : 38,
            child: Column(
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
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
