import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/messaging/domain/messaging_repository.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class BookingCheckoutScreen extends ConsumerStatefulWidget {
  const BookingCheckoutScreen({required this.booking, super.key});

  final SeatBooking booking;

  @override
  ConsumerState<BookingCheckoutScreen> createState() =>
      _BookingCheckoutScreenState();
}

class _BookingCheckoutScreenState extends ConsumerState<BookingCheckoutScreen> {
  static const _method = BookingPaymentMethod.card;
  BookingPaymentQuote? _quote;
  bool _loading = true;
  bool _paying = false;
  String? _error;
  int _quoteRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    final request = ++_quoteRequest;
    final method = _method;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quote = await ref
          .read(bookingRepositoryProvider)
          .quoteBookingPayment(widget.booking.id, method);
      if (mounted && request == _quoteRequest) {
        setState(() => _quote = quote);
      }
    } on AppFailure catch (error) {
      if (mounted && request == _quoteRequest) {
        setState(() => _error = error.message);
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted && request == _quoteRequest) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pay() async {
    if (_quote == null || _paying) return;
    setState(() {
      _paying = true;
      _error = null;
    });
    try {
      final booking = await ref
          .read(bookingRepositoryProvider)
          .payForBooking(widget.booking.id, _method);
      if (!mounted) return;
      Navigator.pop(context, booking);
    } on AppFailure catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                children: [
                  Text(
                    '${widget.booking.originName} → ${widget.booking.destinationName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatShortDate(widget.booking.departureAt)} · ${formatTime(widget.booking.departureAt)} · ${widget.booking.seat.label} seat',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (widget.booking.pickupLocation != null ||
                      widget.booking.dropoffLocation != null) ...[
                    const SizedBox(height: 14),
                    _BookingAddressSummary(booking: widget.booking),
                  ],
                  const SizedBox(height: 28),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (quote != null) ...[
                    _AmountRow(
                      label: 'Subtotal',
                      value: quote.label(quote.baseFareCents),
                    ),
                    _AmountRow(
                      label: 'Platform fee',
                      value: quote.label(quote.serviceFeeCents),
                    ),
                    _AmountRow(
                      label: 'Stripe fee',
                      value: quote.label(quote.processingFeeCents),
                    ),
                    const Divider(height: 24),
                    _AmountRow(
                      label: 'Total',
                      value: quote.totalLabel,
                      emphasized: true,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Held by Stripe. Released after pickup.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Full refund 7+ days before departure. 50% refund 24 hours–7 days before departure. No refund within 24 hours.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
              child: FilledButton(
                onPressed: _loading || _paying || quote == null ? null : _pay,
                child: Text(
                  _paying ? 'Processing…' : 'Pay ${quote?.totalLabel ?? ''}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  bool _adding = false;
  late Future<List<SavedPaymentMethod>> _methods;

  @override
  void initState() {
    super.initState();
    _methods = ref.read(bookingRepositoryProvider).listPaymentMethods();
  }

  Future<void> _add() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final added = await ref
          .read(bookingRepositoryProvider)
          .addPaymentMethod(BookingPaymentMethod.card);
      if (mounted && added) {
        showAppNotice(context, 'Payment method added.');
        setState(() {
          _methods = ref.read(bookingRepositoryProvider).listPaymentMethods();
        });
      }
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment methods')),
      body: FutureBuilder<List<SavedPaymentMethod>>(
        future: _methods,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final methods = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            children: [
              for (var index = 0; index < methods.length; index++) ...[
                _MethodCard(method: methods[index], selected: index == 0),
                const SizedBox(height: 10),
              ],
              OutlinedButton(
                onPressed: _adding ? null : _add,
                child: Text(_adding ? 'Opening Stripe…' : 'Add payment method'),
              ),
              const SizedBox(height: 24),
              const _InfoPanel(
                title: 'Stored by Stripe',
                body: 'SideCar never sees your card number.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: FutureBuilder<List<SeatBooking>>(
        future: ref
            .read(bookingRepositoryProvider)
            .listMyBookings(forceRefresh: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookings = (snapshot.data ?? const <SeatBooking>[])
              .where((booking) => booking.hasFinancialActivity)
              .toList();
          if (bookings.isEmpty) {
            return const Center(child: Text('No payments yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            itemCount: bookings.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                title: Text(_paymentHistoryTitle(booking)),
                subtitle: Text(formatShortDate(booking.departureAt)),
                trailing: Text(
                  booking.totalCents > 0 ? booking.totalLabel : '—',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PayoutMethodsScreen extends ConsumerStatefulWidget {
  const PayoutMethodsScreen({super.key});

  @override
  ConsumerState<PayoutMethodsScreen> createState() =>
      _PayoutMethodsScreenState();
}

class _PayoutMethodsScreenState extends ConsumerState<PayoutMethodsScreen> {
  late Future<DriverPayoutStatus> _status;

  @override
  void initState() {
    super.initState();
    _status = ref.read(bookingRepositoryProvider).getDriverPayoutStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout methods')),
      body: FutureBuilder<DriverPayoutStatus>(
        future: _status,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final status = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            children: [
              if (status?.last4.isNotEmpty == true)
                _PaymentChoiceTile(
                  title: '${status!.bankName} •${status.last4}',
                  subtitle: status.payoutsEnabled
                      ? 'Ready for payouts'
                      : 'Finish payout verification',
                  selected: true,
                )
              else
                const _InfoPanel(
                  title: 'Secure Stripe payouts',
                  body: 'Connect a bank account to receive ride earnings.',
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  status?.connected == true
                      ? 'Manage with Stripe'
                      : 'Set up payouts',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Payouts land 1–2 business days after each completed trip.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class PayoutHistoryScreen extends ConsumerWidget {
  const PayoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(bookingRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payout history')),
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([
          repository.getDriverPayoutStatus(),
          repository.listRideRequests(forceRefresh: true),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final status = snapshot.data?[0] as DriverPayoutStatus?;
          final bookings = snapshot.data?[1] as List<SeatBooking>? ?? const [];
          final paid = bookings
              .where(
                (booking) =>
                    booking.payoutStatus == 'paid' &&
                    booking.driverPayoutCents > 0,
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PAYOUT BALANCE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _money(
                        (status?.availableCents ?? 0) +
                            (status?.pendingCents ?? 0),
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (paid.isEmpty)
                const Text('No payouts yet.')
              else
                for (final booking in paid) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${booking.originName} → ${booking.destinationName}',
                    ),
                    subtitle: Text(formatShortDate(booking.departureAt)),
                    trailing: Text(_money(booking.driverPayoutCents)),
                  ),
                  const Divider(height: 1),
                ],
            ],
          );
        },
      ),
    );
  }
}

class PickupCodeScreen extends ConsumerWidget {
  const PickupCodeScreen({required this.booking, super.key});

  final SeatBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = (booking.pickupCode ?? '----').padRight(4, '-');
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "You're booked",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 5),
              Text(
                '${formatShortDate(booking.departureAt)} · ${formatTime(booking.departureAt)} · ${booking.originName} pickup',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 50),
              const Text(
                'YOUR PICKUP CODE:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mutedInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < 4; index++) ...[
                    _CodeDigit(value: code[index]),
                    if (index < 3) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 30),
              Text(
                'Read this to ${booking.driverName} when you hop in. It starts the trip and releases payment.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'No code, no charge.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 28),
              const _InfoPanel(
                title: '',
                body:
                    "You never pay for a ride that didn't happen — and drivers can't claim no-shows.",
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          final conversation = await ref
                              .read(messagingRepositoryProvider)
                              .openBookingConversation(booking.id);
                          if (context.mounted) {
                            context.push(
                              AppRoutes.chat.replaceFirst(
                                ':conversationId',
                                conversation.id,
                              ),
                            );
                          }
                        } on AppFailure catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.message)),
                            );
                          }
                        }
                      },
                      child: const Text('Message'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('View trip'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentChoiceTile extends StatelessWidget {
  const _PaymentChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final String title;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BookingAddressSummary extends StatelessWidget {
  const _BookingAddressSummary({required this.booking});

  final SeatBooking booking;

  @override
  Widget build(BuildContext context) {
    final pickup = booking.pickupLocation;
    final dropoff = booking.dropoffLocation;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.method, required this.selected});

  final SavedPaymentMethod method;
  final bool selected;

  @override
  Widget build(BuildContext context) => _PaymentChoiceTile(
    title: method.label,
    subtitle: method.detail,
    selected: selected,
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
          ],
          Text(body, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CodeDigit extends StatelessWidget {
  const _CodeDigit({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(value, style: Theme.of(context).textTheme.headlineLarge),
    );
  }
}

String _paymentHistoryTitle(SeatBooking booking) => switch (booking.status) {
  BookingStatus.refunded => 'Refund — ride cancelled',
  BookingStatus.cancelled => 'Cancelled ride',
  _ =>
    'Ride with ${booking.driverName} · ${booking.originName} → ${booking.destinationName}',
};

String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
