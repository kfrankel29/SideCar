import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/core/widgets/sidecar_scaffold.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class SafetyToolsScreen extends ConsumerWidget {
  const SafetyToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsers = ref.watch(blockedUsersProvider);
    return SideCarScaffold(
      showBack: true,
      bottom: Text(
        "Blocked users can't see your activity or message you.",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'Blocked users',
            description: 'People hidden from you across the app.',
          ),
          const SizedBox(height: 24),
          blockedUsers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Column(
              children: [
                const Text('Blocked users could not be loaded.'),
                TextButton(
                  onPressed: () => ref.invalidate(blockedUsersProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
            data: (users) => users.isEmpty
                ? const SideCarInfoCard(
                    title: 'No blocked users',
                    message: 'People you block will appear here.',
                  )
                : Column(
                    children: [
                      for (final user in users)
                        _BlockedUserRow(
                          user: user,
                          onUnblocked: () =>
                              ref.invalidate(blockedUsersProvider),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUserRow extends ConsumerStatefulWidget {
  const _BlockedUserRow({required this.user, required this.onUnblocked});

  final BlockedUser user;
  final VoidCallback onUnblocked;

  @override
  ConsumerState<_BlockedUserRow> createState() => _BlockedUserRowState();
}

class _BlockedUserRowState extends ConsumerState<_BlockedUserRow> {
  bool _saving = false;

  Future<void> _unblock() async {
    setState(() => _saving = true);
    try {
      await ref.read(safetyRepositoryProvider).unblockUser(widget.user.id);
      widget.onUnblocked();
    } on AppFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.softSurface,
            foregroundImage: widget.user.photoUrl.isEmpty
                ? null
                : NetworkImage(widget.user.photoUrl),
            child: widget.user.photoUrl.isEmpty
                ? Text(widget.user.initials)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.user.blockedAt case final blockedAt?)
                  Text(
                    'Blocked ${_shortDate(blockedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: OutlinedButton(
              onPressed: AppHaptics.wrap(_saving ? null : _unblock),
              child: Text(_saving ? 'Wait…' : 'Unblock'),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime value) =>
    '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][value.month - 1]} ${value.day}';

class BlockUserScreen extends ConsumerStatefulWidget {
  const BlockUserScreen({
    required this.targetUserId,
    required this.name,
    super.key,
  });

  final String targetUserId;
  final String name;

  @override
  ConsumerState<BlockUserScreen> createState() => _BlockUserScreenState();
}

class _BlockUserScreenState extends ConsumerState<BlockUserScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _block() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(safetyRepositoryProvider).blockUser(widget.targetUserId);
      ref.invalidate(blockedUsersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${widget.name} was blocked.')));
      context.go('/messages');
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerSurface,
              foregroundColor: AppColors.danger,
            ),
            onPressed: AppHaptics.wrap(_saving ? null : _block),
            child: Text(_saving ? 'Blocking…' : 'Block ${widget.name}'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: AppHaptics.wrap(() => context.pop()),
            child: const Text('Cancel'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenIntro(
            title: 'Block ${widget.name}?',
            description:
                '${widget.name} will no longer be able to see your activity or message you.',
          ),
          const SizedBox(height: 22),
          const SideCarInfoCard(
            title: 'What blocking does',
            message:
                "They won’t appear in your future ride matches. You won’t see each other in search results.",
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.name} won’t be notified that you blocked them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SideCarErrorText(_error),
        ],
      ),
    );
  }
}

class ReportUserScreen extends ConsumerStatefulWidget {
  const ReportUserScreen({
    required this.targetUserId,
    required this.name,
    super.key,
  });

  final String targetUserId;
  final String name;

  @override
  ConsumerState<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends ConsumerState<ReportUserScreen> {
  SafetyReportReason? _reason;
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  Future<void> _submit() async {
    if (_reason == null) {
      setState(() => _error = 'Choose a reason to continue.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(safetyRepositoryProvider)
          .reportUser(targetUserId: widget.targetUserId, reason: _reason!);
      if (!mounted) return;
      setState(() => _submitted = true);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return SideCarScaffold(
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: AppHaptics.wrap(() => context.go('/messages')),
              child: const Text('Done'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: AppHaptics.wrap(
                () => context.go(
                  Uri(
                    path: '/safety/block',
                    queryParameters: {
                      'uid': widget.targetUserId,
                      'name': widget.name,
                    },
                  ).toString(),
                ),
              ),
              child: Text('Also block ${widget.name}'),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 88),
            const Align(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.mutedInk),
                  ),
                ),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: Icon(
                    Icons.check_rounded,
                    size: 34,
                    color: AppColors.mutedInk,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Report submitted',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Our team reviews reports within 24 hours.\nWe may follow up by email.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            SideCarInfoCard(
              title: 'Private by default',
              message: '${widget.name} won\u2019t see that you reported them.',
            ),
            const SizedBox(height: 120),
          ],
        ),
      );
    }

    return SideCarScaffold(
      showBack: true,
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(_saving ? null : _submit),
        child: Text(_saving ? 'Submitting…' : 'Continue'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenIntro(
            title: 'Report ${widget.name}',
            description: 'Choose the reason that best describes what happened.',
          ),
          const SizedBox(height: 20),
          for (final reason in SafetyReportReason.values) ...[
            _ReasonTile(
              reason: reason,
              selected: _reason == reason,
              onTap: () => setState(() {
                _reason = reason;
                _error = null;
              }),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'For emergencies, call 911 first. Reports are reviewed by SideCar support.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SideCarErrorText(_error),
        ],
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final SafetyReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: AppHaptics.wrap(onTap),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? AppColors.softSurface : Colors.white,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    reason.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.chevron_right_rounded,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
