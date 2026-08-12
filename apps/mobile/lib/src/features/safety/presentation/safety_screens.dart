import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/core/widgets/sidecar_scaffold.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class SafetyToolsScreen extends StatefulWidget {
  const SafetyToolsScreen({super.key});

  @override
  State<SafetyToolsScreen> createState() => _SafetyToolsScreenState();
}

class _SafetyToolsScreenState extends State<SafetyToolsScreen> {
  final _uid = TextEditingController();
  final _name = TextEditingController(text: 'Jordan');

  @override
  void dispose() {
    _uid.dispose();
    _name.dispose();
    super.dispose();
  }

  void _open(String route) {
    final uid = _uid.text.trim();
    if (uid.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a SideCar user ID.')));
      return;
    }
    context.push(
      Uri(
        path: route,
        queryParameters: {'uid': uid, 'name': _name.text.trim()},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'Safety & reporting',
            description:
                'Enter the SideCar account you want to block or report.',
          ),
          const SizedBox(height: 22),
          FormFieldBlock(
            label: 'User ID',
            child: TextField(
              controller: _uid,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'Enter user ID'),
            ),
          ),
          const SizedBox(height: 16),
          FormFieldBlock(
            label: 'Display name',
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: AppHaptics.wrap(() => _open(AppRoutes.blockUser)),
            child: const Text('Block user'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: AppHaptics.wrap(() => _open(AppRoutes.reportUser)),
            child: const Text('Report user'),
          ),
        ],
      ),
    );
  }
}

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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${widget.name} was blocked.')));
      context.pop(true);
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
                '${widget.name} will no longer be able to message you or request rides with you.',
          ),
          const SizedBox(height: 22),
          const SideCarInfoCard(
            title: 'What blocking does',
            message:
                'Existing completed trip records remain available for safety and support.',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted.')));
      context.pop();
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
            Icon(
              selected ? Icons.check_circle : Icons.chevron_right_rounded,
              size: 20,
            ),
            const SizedBox(width: 12),
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
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
