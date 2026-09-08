import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/navigation/domain/tab_activation.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/place_picker_sheet.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/profile/domain/public_profile.dart';
import 'package:sidecar/src/features/profile/domain/public_profile_repository.dart';
import 'package:sidecar/src/features/profile/presentation/account_support_screens.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class PostRideScreen extends ConsumerStatefulWidget {
  const PostRideScreen({super.key});

  @override
  ConsumerState<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends ConsumerState<PostRideScreen> {
  final _price = TextEditingController();
  RidePlacePrediction? _origin;
  RidePlacePrediction? _destination;
  DateTime? _date;
  TimeOfDay? _time;
  int? _seats;
  LuggageAllowance? _luggage;
  bool _womenOnly = false;
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
      initialDate: _date ?? DateUtils.dateOnly(DateTime.now()),
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null && mounted) {
      setState(() => _date = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (result != null && mounted) setState(() => _time = result);
  }

  Future<void> _pickLargerSeatCount() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final seats in const [4, 5, 6])
              ListTile(
                title: Text('$seats seats'),
                trailing: _seats == seats
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, seats),
              ),
          ],
        ),
      ),
    );
    if (result != null && mounted) setState(() => _seats = result);
  }

  void _resetForm() {
    _price.clear();
    _origin = null;
    _destination = null;
    _date = null;
    _time = null;
    _seats = null;
    _luggage = null;
    _womenOnly = false;
    _error = null;
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
    if (_time == null) {
      setState(() => _error = 'Select a departure time.');
      return;
    }
    if (_date == null) {
      setState(() => _error = 'Select a departure date.');
      return;
    }
    if (_seats == null) {
      setState(() => _error = 'Select the number of available seats.');
      return;
    }
    if (_luggage == null) {
      setState(() => _error = 'Select the luggage allowance per rider.');
      return;
    }
    final departure = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
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
              seats: _seats!,
              pricePerSeatCents: priceDollars * 100,
              luggageAllowance: _luggage!,
              genderRestriction: _womenOnly
                  ? RideGenderRestriction.womenOnly
                  : RideGenderRestriction.any,
              repeatWeekly: false,
            ),
          );
      if (mounted) {
        setState(_resetForm);
        showAppNotice(context, 'Ride posted successfully.');
        ref.read(mainTabActivationProvider.notifier).activate(2);
        context.go(AppRoutes.myRides);
      }
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
    return RidePageScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 34),
        children: [
          _PageHeader(
            title: 'Post a ride',
            onBack: () => context.go(AppRoutes.home),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 109,
            child: RideRouteCard(
              origin: _origin?.displayName ?? '',
              destination: _destination?.displayName ?? '',
              originPlaceholder: 'Departure City',
              destinationPlaceholder: 'Destination City',
              routeMarkerColor: AppColors.ink,
              locationTextStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
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
                  value: _date == null
                      ? 'Select date'
                      : formatShortDate(_date!),
                  placeholder: _date == null,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TapField(
                  label: 'Time',
                  value: _time?.format(context) ?? 'Select time',
                  placeholder: _time == null,
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Seats'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final seats in [1, 2, 3]) ...[
                          _SeatOption(
                            label: '$seats',
                            selected: _seats == seats,
                            onTap: () => setState(() => _seats = seats),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _SeatOption(
                          label: '4+',
                          selected: (_seats ?? 0) >= 4,
                          onTap: _pickLargerSeatCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 115,
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
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 13, right: 4),
                          child: Align(
                            widthFactor: 1,
                            alignment: Alignment.centerLeft,
                            child: Text('\$'),
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 27,
                          minHeight: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const _Label('Luggage per rider'),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const [
                  (LuggageAllowance.backpack, 'Backpack', 89.0),
                  (LuggageAllowance.oneSuitcase, '1 suitcase', 105.0),
                  (LuggageAllowance.twoPlusBags, '2+ bags', 82.0),
                ]) ...[
                  SizedBox(
                    width: entry.$3,
                    child: RideChoiceChip(
                      label: entry.$2,
                      selected: _luggage == entry.$1,
                      compact: true,
                      onTap: () => setState(() => _luggage = entry.$1),
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
              ],
            ),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Women only'),
                      const SizedBox(height: 2),
                      Text(
                        'Only women can request a seat',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _womenOnly,
                  activeTrackColor: AppColors.primary,
                  onChanged: (value) => setState(() => _womenOnly = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.information,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Drivers must:',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Carry active auto insurance during the trip\n'
                  'Wait 10 minutes past pickup time before marking a no-show\n'
                  'A 5% platform fee is deducted from your total reimbursement.',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: AppColors.secondaryInk,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
          const SizedBox(height: 18),
          FilledButton(
            style: AppButtonStyles.primaryFilled.copyWith(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
            ),
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Posting…' : 'Post ride'),
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

class RiderMyRidesScreen extends ConsumerStatefulWidget {
  const RiderMyRidesScreen({super.key});

  @override
  ConsumerState<RiderMyRidesScreen> createState() => _RiderMyRidesScreenState();
}

class _RiderMyRidesScreenState extends ConsumerState<RiderMyRidesScreen> {
  int _selectedTab = 0;
  late Future<List<SeatBooking>> _bookings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool forceRefresh = false}) {
    _bookings = ref
        .read(bookingRepositoryProvider)
        .listMyBookings(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    final future = ref
        .read(bookingRepositoryProvider)
        .listMyBookings(forceRefresh: true);
    setState(() => _bookings = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myRidesTabActivationProvider, (_, _) {
      if (mounted) setState(() => _load(forceRefresh: true));
    });
    return RidePageScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 27, 24, 0),
            child: Text(
              'My rides',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 29,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _RideTabs(
              selectedIndex: _selectedTab,
              onSelected: (index) => setState(() => _selectedTab = index),
            ),
          ),
          Expanded(
            child: _SwipeableTabBody(
              selectedIndex: _selectedTab,
              onSelected: (index) => setState(() => _selectedTab = index),
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<SeatBooking>>(
                  future: _bookings,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _RefreshableRideMessage(
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return _RefreshableRideMessage(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _load(forceRefresh: true)),
                          child: const Text('Could not load rides · Try again'),
                        ),
                      );
                    }
                    final now = DateTime.now();
                    final bookings = (snapshot.data ?? const <SeatBooking>[])
                        .where(
                          (booking) => switch (_selectedTab) {
                            0 =>
                              [
                                    BookingStatus.confirmed,
                                    BookingStatus.inProgress,
                                  ].contains(booking.status) &&
                                  !booking.departureAt.isBefore(now),
                            1 => [
                              BookingStatus.pendingDriver,
                              BookingStatus.acceptedPaymentPending,
                              BookingStatus.paymentProcessing,
                            ].contains(booking.status),
                            _ =>
                              [
                                    BookingStatus.declined,
                                    BookingStatus.expired,
                                    BookingStatus.cancelled,
                                    BookingStatus.refunded,
                                    BookingStatus.completed,
                                    BookingStatus.lostSeat,
                                  ].contains(booking.status) ||
                                  booking.departureAt.isBefore(now),
                          },
                        )
                        .toList();
                    if (bookings.isEmpty) {
                      return _RefreshableRideMessage(
                        child: Text(switch (_selectedTab) {
                          1 => 'No ride requests.',
                          2 => 'No past rides.',
                          _ => 'No upcoming rides.',
                        }),
                      );
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                      itemCount: bookings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _RiderBookingCard(
                        booking: bookings[index],
                        onChanged: () =>
                            setState(() => _load(forceRefresh: true)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRidesScreenState extends ConsumerState<MyRidesScreen> {
  late Future<List<Ride>> _rides;
  final Set<String> _cancelledRideIds = {};
  Timer? _liveRefreshTimer;
  bool _liveRefreshInProgress = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _liveRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  List<Ride> _applyLocalChanges(List<Ride> rides) {
    return rides
        .map(
          (ride) => _cancelledRideIds.contains(ride.id)
              ? ride.copyWith(
                  status: 'cancelled',
                  seatsAvailable: ride.seatsTotal,
                  bookedSeats: 0,
                )
              : ride,
        )
        .toList(growable: false);
  }

  void _load({bool forceRefresh = false}) => _rides = ref
      .read(rideRepositoryProvider)
      .listMyRides(forceRefresh: forceRefresh)
      .then(_applyLocalChanges);

  Future<void> _refresh() async {
    final request = ref
        .read(rideRepositoryProvider)
        .listMyRides(forceRefresh: true)
        .then(_applyLocalChanges);
    setState(() => _rides = request);
    try {
      await request;
    } on Object {
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted ||
        !TickerMode.getValuesNotifier(context).value.enabled ||
        _liveRefreshInProgress) {
      return;
    }
    _liveRefreshInProgress = true;
    try {
      final rides = await ref
          .read(rideRepositoryProvider)
          .listMyRides(forceRefresh: true);
      if (mounted) {
        setState(() => _rides = Future.value(_applyLocalChanges(rides)));
      }
    } on Object {
      // Keep the last successful state; pull-to-refresh remains available.
    } finally {
      _liveRefreshInProgress = false;
    }
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
        _cancelledRideIds.add(ride.id);
        ref.read(rideRepositoryProvider).invalidateRide(ride.id);
        showAppNotice(
          context,
          'Ride cancelled. Confirmed riders were refunded.',
        );
        setState(() => _load(forceRefresh: true));
      }
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPendingRequests =
        (ref.watch(driverPendingRequestCountProvider).value ?? 0) > 0;
    ref.listen(myRidesTabActivationProvider, (_, _) {
      if (mounted) setState(() => _load(forceRefresh: true));
    });
    return RidePageScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 21, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'My rides',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Post a ride',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => context.go(AppRoutes.postRide),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.softSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 26,
                        color: AppColors.ink,
                        weight: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _RideTabs(
              selectedIndex: _selectedTab,
              showRequestBadge: hasPendingRequests,
              onSelected: (index) => setState(() => _selectedTab = index),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _SwipeableTabBody(
              selectedIndex: _selectedTab,
              onSelected: (index) => setState(() => _selectedTab = index),
              child: _selectedTab == 1
                  ? const _DriverRequestsList()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: FutureBuilder<List<Ride>>(
                        future: _rides,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const _RefreshableRideMessage(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return _RefreshableRideMessage(
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _load(forceRefresh: true)),
                                child: const Text(
                                  'Could not load rides · Try again',
                                ),
                              ),
                            );
                          }
                          final allRides = snapshot.data ?? const [];
                          final now = DateTime.now();
                          final rides = switch (_selectedTab) {
                            0 =>
                              allRides
                                  .where(
                                    (ride) =>
                                        ride.status == 'published' &&
                                        !ride.departureAt.isBefore(now),
                                  )
                                  .toList(),
                            _ =>
                              allRides
                                  .where(
                                    (ride) =>
                                        ride.status != 'published' ||
                                        ride.departureAt.isBefore(now),
                                  )
                                  .toList()
                                ..sort(
                                  (left, right) => right.departureAt.compareTo(
                                    left.departureAt,
                                  ),
                                ),
                          };
                          if (rides.isEmpty) {
                            return _RefreshableRideMessage(
                              child: Text(
                                _selectedTab == 2
                                    ? 'No past rides.'
                                    : 'No upcoming rides.',
                              ),
                            );
                          }
                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: rides.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) => _ManagedRideCard(
                              ride: rides[index],
                              onView: () =>
                                  context.push('/rides/${rides[index].id}'),
                              onCancel: () => _cancelRide(rides[index]),
                              showActions: _selectedTab == 0,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshableRideMessage extends StatelessWidget {
  const _RefreshableRideMessage({required this.child});

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

class _DriverRequestsList extends ConsumerStatefulWidget {
  const _DriverRequestsList();

  @override
  ConsumerState<_DriverRequestsList> createState() =>
      _DriverRequestsListState();
}

class _DriverRequestsListState extends ConsumerState<_DriverRequestsList> {
  late Future<List<SeatBooking>> _requests;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({bool forceRefresh = false}) {
    _requests = ref
        .read(bookingRepositoryProvider)
        .listRideRequests(forceRefresh: forceRefresh);
  }

  Future<void> _refresh() async {
    final future = ref
        .read(bookingRepositoryProvider)
        .listRideRequests(forceRefresh: true);
    setState(() => _requests = future);
    await future;
  }

  Future<void> _respond(SeatBooking booking, bool accept) async {
    setState(() => _busyId = booking.id);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .respondToRequest(booking.id, accept: accept);
      if (mounted) {
        ref.invalidate(driverPendingRequestCountProvider);
        showAppNotice(
          context,
          accept ? 'Seat request accepted.' : 'Seat request declined.',
        );
        setState(() => _load(forceRefresh: true));
      }
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<SeatBooking>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _RefreshableRideMessage(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return _RefreshableRideMessage(
              child: TextButton(
                onPressed: () => setState(() => _load(forceRefresh: true)),
                child: const Text('Could not load requests · Try again'),
              ),
            );
          }
          final requests = (snapshot.data ?? const <SeatBooking>[])
              .where((booking) => booking.status == BookingStatus.pendingDriver)
              .toList();
          if (requests.isEmpty) {
            return const _RefreshableRideMessage(
              child: Text('No ride requests.'),
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final booking = requests[index];
              final busy = _busyId == booking.id;
              return _DriverRequestCard(
                booking: booking,
                busy: busy,
                onDecline: () => _respond(booking, false),
                onAccept: () => _respond(booking, true),
              );
            },
          );
        },
      ),
    );
  }
}

class _DriverRequestCard extends ConsumerStatefulWidget {
  const _DriverRequestCard({
    required this.booking,
    required this.busy,
    required this.onDecline,
    required this.onAccept,
  });

  final SeatBooking booking;
  final bool busy;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  @override
  ConsumerState<_DriverRequestCard> createState() => _DriverRequestCardState();
}

class _DriverRequestCardState extends ConsumerState<_DriverRequestCard> {
  late Future<PublicProfile> _profile;

  @override
  void initState() {
    super.initState();
    _profile = ref
        .read(publicProfileRepositoryProvider)
        .getProfile(widget.booking.riderId);
  }

  @override
  void didUpdateWidget(covariant _DriverRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.riderId != widget.booking.riderId) {
      _profile = ref
          .read(publicProfileRepositoryProvider)
          .getProfile(widget.booking.riderId);
    }
  }

  String _priceLabel(int cents) => '\$${(cents / 100).round()}';

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return FutureBuilder<PublicProfile>(
      future: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return RideSummaryCard(
          origin: booking.originName,
          destination: booking.destinationName,
          dateLabel: formatShortDate(booking.departureAt),
          timeLabel: formatTime(booking.departureAt),
          priceLabel: _priceLabel(booking.baseFareCents),
          bookedLabel: 'Seat requested',
          profileName: booking.riderName,
          profileInitials: booking.riderInitials,
          profilePhotoUrl: booking.riderPhotoUrl,
          profileRating: profile?.rating,
          keyPrefix: 'driver-request-${booking.id}',
          onTap: () => context.push('/profiles/${booking.riderId}'),
          footer: Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.dangerSurface,
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: widget.busy ? null : widget.onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE5F3EA),
                    foregroundColor: const Color(0xFF167A52),
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: widget.busy ? null : widget.onAccept,
                  child: Text(widget.busy ? 'Please wait…' : 'Accept'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RiderBookingCard extends ConsumerStatefulWidget {
  const _RiderBookingCard({required this.booking, required this.onChanged});

  final SeatBooking booking;
  final VoidCallback onChanged;

  @override
  ConsumerState<_RiderBookingCard> createState() => _RiderBookingCardState();
}

class _RiderBookingCardState extends ConsumerState<_RiderBookingCard> {
  bool _busy = false;
  late Future<PublicProfile> _driverProfile;

  @override
  void initState() {
    super.initState();
    _driverProfile = ref
        .read(publicProfileRepositoryProvider)
        .getProfile(widget.booking.driverId);
  }

  @override
  void didUpdateWidget(covariant _RiderBookingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.driverId != widget.booking.driverId) {
      _driverProfile = ref
          .read(publicProfileRepositoryProvider)
          .getProfile(widget.booking.driverId);
    }
  }

  String _priceLabel(int cents) => '\$${(cents / 100).round()}';

  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showAppNotice(context, successMessage);
      widget.onChanged();
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final result = await Navigator.of(context).push<SeatBooking>(
      MaterialPageRoute(
        builder: (_) => BookingCheckoutScreen(booking: widget.booking),
      ),
    );
    if (result != null) {
      if (mounted) {
        showAppNotice(context, 'Payment complete. Your seat is confirmed.');
      }
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final action = switch (booking.status) {
      BookingStatus.pendingDriver => (
        'Not charged until ${booking.driverName} accepts',
        'Cancel request',
        () => _run(
          () => ref.read(bookingRepositoryProvider).cancelBooking(booking.id),
          successMessage: 'Seat request cancelled.',
        ),
      ),
      BookingStatus.acceptedPaymentPending || BookingStatus.paymentProcessing =>
        ('Pay within 24h to hold your seat', 'Pay ${booking.totalLabel}', _pay),
      BookingStatus.confirmed => (
        'Paid · pickup code ready',
        'View code',
        () async {
          final viewTrip = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PickupCodeScreen(booking: booking),
            ),
          );
          if (viewTrip == true && context.mounted) {
            context.push('/rides/${booking.rideId}');
          }
        },
      ),
      _ => (_bookingStatusLabel(booking.status), '', () async {}),
    };
    return FutureBuilder<PublicProfile>(
      future: _driverProfile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final actionBackground = switch (booking.status) {
          BookingStatus.pendingDriver => AppColors.dangerSurface,
          BookingStatus.acceptedPaymentPending ||
          BookingStatus.paymentProcessing => AppColors.primary,
          _ => AppColors.softSurface,
        };
        final actionForeground = switch (booking.status) {
          BookingStatus.pendingDriver => AppColors.danger,
          BookingStatus.acceptedPaymentPending ||
          BookingStatus.paymentProcessing => Colors.white,
          _ => AppColors.primary,
        };
        return RideSummaryCard(
          origin: booking.originName,
          destination: booking.destinationName,
          dateLabel: formatShortDate(booking.departureAt),
          timeLabel: formatTime(booking.departureAt),
          priceLabel: _priceLabel(booking.baseFareCents),
          bookedLabel: _bookingStatusLabel(booking.status),
          profileName: booking.driverName,
          profileInitials: booking.driverName
              .split(' ')
              .take(2)
              .map((part) => part.isEmpty ? '' : part[0])
              .join(),
          profilePhotoUrl: booking.driverPhotoUrl,
          profileRating: profile?.rating,
          keyPrefix: 'rider-booking-${booking.id}',
          onTap: () => context.push('/rides/${booking.rideId}'),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                action.$1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedInk,
                  fontSize: 11,
                ),
              ),
              if (action.$2.isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: actionBackground,
                    foregroundColor: actionForeground,
                    minimumSize: const Size(0, 40),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _busy ? null : action.$3,
                  child: Text(_busy ? 'Please wait…' : action.$2),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

String _bookingStatusLabel(BookingStatus status) => switch (status) {
  BookingStatus.pendingDriver => 'Pending',
  BookingStatus.acceptedPaymentPending ||
  BookingStatus.paymentProcessing => 'Accepted',
  BookingStatus.confirmed => 'Confirmed',
  BookingStatus.inProgress => 'In progress',
  BookingStatus.completed => 'Completed',
  BookingStatus.declined => 'Declined',
  BookingStatus.expired => 'Expired',
  BookingStatus.cancelled => 'Cancelled',
  BookingStatus.refunded || BookingStatus.lostSeat => 'Refunded',
  BookingStatus.disputed => 'Disputed',
  BookingStatus.payoutHeld => 'Under review',
  BookingStatus.cancellationProcessing => 'Cancelling',
  BookingStatus.completionProcessing => 'Completing',
};

class _RideTabs extends StatelessWidget {
  const _RideTabs({
    required this.selectedIndex,
    required this.onSelected,
    this.showRequestBadge = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showRequestBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          for (final entry in const [
            (0, 'Upcoming'),
            (1, 'Requests'),
            (2, 'Past'),
          ])
            Expanded(
              child: _RideListTab(
                label: entry.$2,
                selected: selectedIndex == entry.$1,
                showBadge: entry.$1 == 1 && showRequestBadge,
                onTap: () => onSelected(entry.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwipeableTabBody extends StatelessWidget {
  const _SwipeableTabBody({
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 180) return;
        final next = velocity < 0 ? selectedIndex + 1 : selectedIndex - 1;
        if (next >= 0 && next <= 2) onSelected(next);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(key: ValueKey(selectedIndex), child: child),
      ),
    );
  }
}

class _RideListTab extends StatelessWidget {
  const _RideListTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? Colors.white : AppColors.mutedInk,
                ),
              ),
              if (showBadge) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE14942),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagedRideCard extends StatelessWidget {
  const _ManagedRideCard({
    required this.ride,
    required this.onView,
    required this.onCancel,
    required this.showActions,
  });

  final Ride ride;
  final VoidCallback onView;
  final VoidCallback onCancel;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return RideSummaryCard(
      origin: ride.origin.displayName,
      destination: ride.destination.displayName,
      dateLabel: formatShortDate(ride.departureAt),
      timeLabel: formatTime(ride.departureAt),
      priceLabel: ride.priceLabel,
      bookedLabel: '${ride.bookedSeats}/${ride.seatsTotal} booked',
      onTap: onView,
      keyPrefix: 'managed-ride-${ride.id}',
      footer: showActions
          ? Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFE2DE),
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(0, 34),
                      maximumSize: const Size(double.infinity, 34),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: onCancel,
                    child: const Text('Cancel ride'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.softSurface,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(0, 34),
                      maximumSize: const Size(double.infinity, 34),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
            )
          : Text(
              _managedRideStatusLabel(ride.status),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

String _managedRideStatusLabel(String status) => switch (status) {
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  'in_progress' => 'In progress',
  _ =>
    status
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' '),
};

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 38,
                ),
                onPressed: onBack,
                icon: const FinalDraftBackIcon(size: 30),
              ),
            ),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
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
    this.placeholder = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool placeholder;

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
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: placeholder ? AppColors.mutedInk : AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
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

class _SeatOption extends StatelessWidget {
  const _SeatOption({
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? Colors.white : AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
