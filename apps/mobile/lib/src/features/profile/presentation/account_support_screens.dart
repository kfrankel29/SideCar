import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/core/widgets/sidecar_scaffold.dart';
import 'package:sidecar/src/core/widgets/password_field.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/profile/domain/account_security_repository.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _deleting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_controller.text.trim() != 'DELETE' || _deleting) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(accountSecurityRepositoryProvider)
          .deleteAccount(confirmation: _controller.text.trim());
      if (mounted) context.go(AppRoutes.welcome);
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _controller.text.trim() == 'DELETE' && !_deleting;
    return _FinalDraftPage(
      title: 'Delete your account?',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This permanently removes your profile, rides, and messages once open trips finish.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 26),
          const SideCarInfoCard(
            title: 'Before deletion',
            message:
                'Pending payouts and refunds are settled first.\nTrip records required for safety may be retained as our policy allows.',
            color: AppColors.warning,
          ),
          const SizedBox(height: 14),
          const FieldLabel('Type DELETE to confirm'),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'DELETE'),
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerSurface,
              foregroundColor: AppColors.danger,
              disabledBackgroundColor: AppColors.dangerSurface,
              disabledForegroundColor: AppColors.mutedInk,
            ),
            onPressed: canDelete ? AppHaptics.wrap(_delete) : null,
            child: Text(_deleting ? 'Deleting…' : 'Delete account'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _deleting
                ? null
                : AppHaptics.wrap(() => Navigator.maybePop(context)),
            child: const Text('Keep my account'),
          ),
        ],
      ),
    );
  }
}

class CancelRideConfirmationScreen extends StatelessWidget {
  const CancelRideConfirmationScreen({required this.ride, super.key});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return _FinalDraftPage(
      title: 'Cancel this ride?',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${formatShortDate(ride.departureAt)} · ${ride.origin.displayName} → ${ride.destination.displayName} · ${ride.bookedSeats} ${ride.bookedSeats == 1 ? 'rider' : 'riders'} booked',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 26),
          const SideCarInfoCard(
            title: 'What happens',
            message:
                'Confirmed riders are notified and fully refunded no matter how close to departure. Frequent cancellations can pause your ability to post.',
            color: AppColors.warning,
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerSurface,
              foregroundColor: AppColors.danger,
            ),
            onPressed: AppHaptics.wrap(() => Navigator.pop(context, true)),
            child: const Text('Cancel ride'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: AppHaptics.wrap(() => Navigator.pop(context, false)),
            child: const Text('Keep ride'),
          ),
        ],
      ),
    );
  }
}

class CancellationPolicyScreen extends StatelessWidget {
  const CancellationPolicyScreen({super.key, this.ride, this.onCancel});

  final Ride? ride;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return _FinalDraftPage(
      title: 'Cancellation policy',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.softSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'Free until 7 days before your ride',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Cancel up to 7 days out — full refund, automatic.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('HOW IT WORKS', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 12),
          const _PolicyStep(
            title: 'More than 7 days before',
            message: 'Free cancellation. 100% refunded in 1–2 business days.',
            position: _PolicyPosition.first,
          ),
          const _PolicyStep(
            title: 'Within 7 days of departure',
            message: '50% refunded — your driver planned around your seat.',
            position: _PolicyPosition.middle,
            active: true,
          ),
          const _PolicyStep(
            title: 'If your driver cancels',
            message: 'You’re always fully refunded, no matter when.',
            position: _PolicyPosition.last,
          ),
          if (ride != null) ...[
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                        Text(
                          'Your ride · ${formatShortDate(ride!.departureAt)}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Free cancellation ends ${formatMonthDay(ride!.departureAt.subtract(const Duration(days: 7)))}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 106,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.dangerSurface,
                        foregroundColor: AppColors.danger,
                      ),
                      onPressed: onCancel == null
                          ? null
                          : AppHaptics.wrap(onCancel!),
                      child: const Text('Cancel ride'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  final _search = TextEditingController();
  int _expanded = 1;

  static const _items = <(String, String)>[
    (
      'How do refunds work?',
      'Eligible refunds return to the original payment method. Most appear in 1–2 business days.',
    ),
    (
      'What happens if I cancel?',
      'More than 7 days before departure is fully refundable. Within 7 days, 50% is refunded. Driver cancellations are always fully refunded.',
    ),
    (
      'How do I contact my driver or rider?',
      'Open Messages and choose the conversation linked to your ride.',
    ),
    (
      'When do drivers receive payouts?',
      'Payouts are released after a completed trip and normally arrive based on the connected Stripe payout schedule.',
    ),
    (
      'How do verification and safety reports work?',
      'Verification protects the community. Reports are reviewed by SideCar admins and remain private.',
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = <(int, (String, String))>[
      for (var index = 0; index < _items.length; index++)
        if (query.isEmpty ||
            _items[index].$1.toLowerCase().contains(query) ||
            _items[index].$2.toLowerCase().contains(query))
          (index, _items[index]),
    ];
    return _FinalDraftPage(
      title: 'Help & FAQs',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Search questions…'),
          ),
          const SizedBox(height: 12),
          for (final entry in visible)
            _FaqRow(
              question: entry.$2.$1,
              answer: entry.$2.$2,
              expanded: _expanded == entry.$1,
              onTap: () => setState(
                () => _expanded = _expanded == entry.$1 ? -1 : entry.$1,
              ),
            ),
          const SizedBox(height: 34),
          OutlinedButton(
            onPressed: AppHaptics.wrap(
              () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const CancellationPolicyScreen(),
                ),
              ),
            ),
            child: const Text('View full cancellation policy'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: AppHaptics.wrap(() => context.go(AppRoutes.messages)),
            child: const Text('Chat with support'),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      _current.text.isNotEmpty &&
      _next.text.length >= 8 &&
      RegExp(r'\d').hasMatch(_next.text) &&
      _next.text == _confirm.text &&
      !_saving;

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(accountSecurityRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      showAppNotice(context, 'Password updated.');
      Navigator.pop(context);
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FinalDraftPage(
      title: 'Change password',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PasswordBlock(
            label: 'Current password',
            controller: _current,
            onChanged: _refresh,
          ),
          const SizedBox(height: 18),
          _PasswordBlock(
            label: 'New password',
            controller: _next,
            hint: '8+ characters, one number',
            onChanged: _refresh,
          ),
          const SizedBox(height: 18),
          _PasswordBlock(
            label: 'Confirm new password',
            controller: _confirm,
            hint: 'Repeat new password',
            onChanged: _refresh,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: AppHaptics.wrap(
                () => context.push(AppRoutes.forgotPassword),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.ink,
              ),
              child: const Text('Forgot your current password? Reset by email'),
            ),
          ),
        ],
      ),
      bottom: FilledButton(
        onPressed: _valid ? AppHaptics.wrap(_save) : null,
        child: Text(_saving ? 'Updating…' : 'Update password'),
      ),
    );
  }

  void _refresh(String _) => setState(() {});
}

class _PasswordBlock extends StatelessWidget {
  const _PasswordBlock({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: label,
      child: PasswordFormField(
        controller: controller,
        onChanged: onChanged,
        hintText: hint,
      ),
    );
  }
}

class _FinalDraftPage extends StatelessWidget {
  const _FinalDraftPage({required this.title, required this.body, this.bottom});

  final String title;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: AppHaptics.wrap(
                        () => Navigator.maybePop(context),
                      ),
                      icon: const FinalDraftBackIcon(size: 28),
                    ),
                  ),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: body,
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

enum _PolicyPosition { first, middle, last }

class _PolicyStep extends StatelessWidget {
  const _PolicyStep({
    required this.title,
    required this.message,
    required this.position,
    this.active = false,
  });

  final String title;
  final String message;
  final _PolicyPosition position;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            height: 104,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (position != _PolicyPosition.first)
                  const Positioned(top: 0, bottom: 58, child: _DottedLine()),
                if (position != _PolicyPosition.last)
                  const Positioned(top: 15, bottom: 0, child: _DottedLine()),
                Positioned(
                  top: 3,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : AppColors.ink,
                      shape: BoxShape.circle,
                      border: active
                          ? Border.all(color: AppColors.ink, width: 2)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(1, double.infinity),
    painter: _DottedLinePainter(),
  );
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(0, y + 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: AppHaptics.wrap(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                FinalDraftChevronIcon(
                  direction: expanded
                      ? FinalDraftChevronDirection.up
                      : FinalDraftChevronDirection.down,
                  size: 17,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              Text(
                answer,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
