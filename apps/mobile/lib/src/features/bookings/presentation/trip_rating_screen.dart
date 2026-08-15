import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class TripRatingScreen extends ConsumerStatefulWidget {
  const TripRatingScreen({required this.booking, super.key});

  final SeatBooking booking;

  @override
  ConsumerState<TripRatingScreen> createState() => _TripRatingScreenState();
}

class _TripRatingScreenState extends ConsumerState<TripRatingScreen> {
  final _commentController = TextEditingController();
  int _driverRating = 0;
  int _tripRating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_driverRating == 0 || _tripRating == 0) {
      showAppNotice(
        context,
        'Choose a rating for the driver and the trip.',
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
            tripRating: _tripRating,
            comment: _commentController.text,
          );
      if (!mounted) return;
      showAppNotice(context, 'Thanks for rating your trip.');
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      onPressed: Navigator.of(context).pop,
                      icon: const FinalDraftBackIcon(size: 23),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Rate driver and trip',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your feedback helps keep every SideCar trip safe and reliable.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 34),
                  _RatingSection(
                    title: 'How was ${widget.booking.driverName}?',
                    value: _driverRating,
                    onChanged: (value) => setState(() => _driverRating = value),
                  ),
                  const SizedBox(height: 30),
                  _RatingSection(
                    title: 'How was the trip?',
                    value: _tripRating,
                    onChanged: (value) => setState(() => _tripRating = value),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Anything else? (optional)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commentController,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 800,
                    decoration: const InputDecoration(
                      hintText: 'Share a few details about your experience',
                      alignLabelWithHint: true,
                    ),
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
                child: Text(_submitting ? 'Submitting…' : 'Submit rating'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Row(
        children: [
          for (var rating = 1; rating <= 5; rating++) ...[
            Semantics(
              button: true,
              selected: value == rating,
              label: '$rating stars',
              child: IconButton(
                key: ValueKey('$title-$rating'),
                tooltip: '$rating stars',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => onChanged(rating),
                icon: Icon(
                  rating <= value ? Icons.star : Icons.star_border,
                  color: AppColors.ink,
                  size: 32,
                ),
              ),
            ),
            if (rating < 5) const SizedBox(width: 4),
          ],
        ],
      ),
    ],
  );
}
