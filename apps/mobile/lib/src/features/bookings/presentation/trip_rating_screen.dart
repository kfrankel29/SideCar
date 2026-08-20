import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/navigation/domain/tab_activation.dart';
import 'package:sidecar/src/theme/app_theme.dart';
import 'package:sidecar/src/routing/app_router.dart';

class TripRatingScreen extends ConsumerStatefulWidget {
  const TripRatingScreen({required this.booking, super.key});

  final SeatBooking booking;

  @override
  ConsumerState<TripRatingScreen> createState() => _TripRatingScreenState();
}

class _TripRatingScreenState extends ConsumerState<TripRatingScreen> {
  final _commentController = TextEditingController();
  int _driverRating = 0;
  final Set<String> _compliments = {};
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_driverRating == 0) {
      showAppNotice(
        context,
        'Choose a rating for your driver.',
        kind: AppNoticeKind.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .rateTrip(
            bookingId: widget.booking.id,
            driverRating: _driverRating,
            tripRating: _driverRating,
            comment: [
              ..._compliments,
              _commentController.text.trim(),
            ].where((value) => value.isNotEmpty).join(' · '),
          );
      if (!mounted) return;
      showAppNotice(context, 'Thanks for rating your trip.');
      _goHome();
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skip() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .dismissTripRating(widget.booking.id);
      if (mounted) _goHome();
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goHome() {
    ref.read(mainTabActivationProvider.notifier).activate(0);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(AppRoutes.home);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final route =
        '${widget.booking.originName} → ${widget.booking.destinationName}';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
                children: [
                  const Center(child: _CompletedBadge()),
                  const SizedBox(height: 12),
                  Text(
                    'Home safe',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$route · ${widget.booking.totalLabel}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: CircleAvatar(
                      radius: 31,
                      backgroundColor: AppColors.softSurface,
                      foregroundImage: widget.booking.driverPhotoUrl.isEmpty
                          ? null
                          : NetworkImage(widget.booking.driverPhotoUrl),
                      child: widget.booking.driverPhotoUrl.isEmpty
                          ? Text(_initials(widget.booking.driverName))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How was riding with ${_firstName(widget.booking.driverName)}?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: _StarPicker(
                      keyPrefix: 'driver',
                      value: _driverRating,
                      onChanged: (value) =>
                          setState(() => _driverRating = value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in const [
                        'Friendly driver',
                        'Safe driver',
                        'On time',
                      ])
                        _FeedbackChip(
                          label: label,
                          selected: _compliments.contains(label),
                          onTap: () => setState(() {
                            _compliments.contains(label)
                                ? _compliments.remove(label)
                                : _compliments.add(label);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _commentController,
                    maxLength: 800,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Add a note (optional)…',
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.paddingOf(context).bottom + 10,
              ),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Submitting…' : 'Submit rating'),
                  ),
                  TextButton(
                    onPressed: _submitting ? null : _skip,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({
    required this.keyPrefix,
    required this.value,
    required this.onChanged,
  });

  final String keyPrefix;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var rating = 1; rating <= 5; rating++)
        Semantics(
          button: true,
          selected: value == rating,
          label: '$rating stars',
          child: IconButton(
            key: ValueKey('$keyPrefix-$rating'),
            tooltip: '$rating stars',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 42),
            onPressed: () => onChanged(rating),
            icon: Icon(
              rating <= value ? Icons.star : Icons.star_border,
              color: AppColors.ink,
              size: 27,
            ),
          ),
        ),
    ],
  );
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : Colors.white,
        border: Border.all(color: selected ? AppColors.ink : AppColors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: selected ? Colors.white : AppColors.ink,
        ),
      ),
    ),
  );
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.softSurface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '✓  Trip complete',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class RateRidersScreen extends ConsumerStatefulWidget {
  const RateRidersScreen({required this.bookings, super.key});

  final List<SeatBooking> bookings;

  @override
  ConsumerState<RateRidersScreen> createState() => _RateRidersScreenState();
}

class _RateRidersScreenState extends ConsumerState<RateRidersScreen> {
  final Map<String, int> _ratings = {};
  final Set<String> _compliments = {};
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    if (widget.bookings.any((booking) => (_ratings[booking.id] ?? 0) == 0)) {
      showAppNotice(
        context,
        'Choose a rating for each rider.',
        kind: AppNoticeKind.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      for (final booking in widget.bookings) {
        await ref
            .read(bookingRepositoryProvider)
            .rateRider(
              bookingId: booking.id,
              rating: _ratings[booking.id]!,
              comment: _compliments.join(' · '),
            );
      }
      if (!mounted) return;
      showAppNotice(context, 'Thanks for rating your riders.');
      ref.read(mainTabActivationProvider.notifier).activate(0);
      Navigator.pop(context, true);
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnedCents = widget.bookings.fold<int>(
      0,
      (total, booking) => total + booking.driverPayoutCents,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
                children: [
                  const Center(child: _CompletedBadge()),
                  const SizedBox(height: 12),
                  Text(
                    'Nice drive',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'YOU EARNED',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${(earnedCents / 100).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Payment will be deposited into\nyour bank account in 1–2 days.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Rate your riders',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  for (final booking in widget.bookings) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.softSurface,
                            foregroundImage: booking.riderPhotoUrl.isEmpty
                                ? null
                                : NetworkImage(booking.riderPhotoUrl),
                            child: booking.riderPhotoUrl.isEmpty
                                ? Text(booking.riderInitials)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _shortName(booking.riderName),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          _StarPicker(
                            keyPrefix: 'rider-${booking.id}',
                            value: _ratings[booking.id] ?? 0,
                            onChanged: (value) =>
                                setState(() => _ratings[booking.id] = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in const [
                        'On time',
                        'Easy pickup',
                        'Great convo',
                      ])
                        _FeedbackChip(
                          label: label,
                          selected: _compliments.contains(label),
                          onTap: () => setState(() {
                            _compliments.contains(label)
                                ? _compliments.remove(label)
                                : _compliments.add(label);
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                MediaQuery.paddingOf(context).bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.softSurface)),
              ),
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Submitting…' : 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();

String _shortName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) return name;
  return '${parts.first} ${parts.last[0].toUpperCase()}.';
}
