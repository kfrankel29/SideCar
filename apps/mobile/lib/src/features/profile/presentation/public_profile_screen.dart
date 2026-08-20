import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/profile/domain/public_profile.dart';
import 'package:sidecar/src/features/profile/domain/public_profile_repository.dart';
import 'package:sidecar/src/features/messaging/domain/messaging_repository.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  late Future<(PublicProfile, bool)> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<(PublicProfile, bool)> _load() async {
    final results = await Future.wait([
      ref.read(publicProfileRepositoryProvider).getProfile(widget.userId),
      ref.read(safetyRepositoryProvider).isBlocked(widget.userId),
    ]);
    return (results[0] as PublicProfile, results[1] as bool);
  }

  Future<void> _unblock(PublicProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock ${profile.displayName}?'),
        content: const Text(
          'You will be able to find and request rides with each other again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(safetyRepositoryProvider).unblockUser(widget.userId);
      if (!mounted) return;
      showAppNotice(context, '${profile.displayName} was unblocked.');
      setState(() => _data = Future.value((profile, false)));
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    }
  }

  Future<void> _block(PublicProfile profile) async {
    final blocked = await context.push<bool>(
      '${AppRoutes.blockUser}?uid=${Uri.encodeQueryComponent(profile.userId)}&name=${Uri.encodeQueryComponent(profile.displayName)}',
    );
    if (blocked == true && mounted) {
      setState(() => _data = Future.value((profile, true)));
    }
  }

  Future<void> _message(PublicProfile profile) async {
    try {
      final conversation = await ref
          .read(messagingRepositoryProvider)
          .openDirectConversation(profile.userId);
      if (!mounted) return;
      context.push('/messages/${conversation.id}');
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<(PublicProfile, bool)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            final message = snapshot.error is AppFailure
                ? (snapshot.error! as AppFailure).message
                : 'That profile is unavailable.';
            return Center(child: Text(message));
          }
          final data = snapshot.data!;
          return _ProfileBody(
            profile: data.$1,
            blocked: data.$2,
            onBlock: () => _block(data.$1),
            onUnblock: () => _unblock(data.$1),
            onMessage: () => _message(data.$1),
          );
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.blocked,
    required this.onBlock,
    required this.onUnblock,
    required this.onMessage,
  });

  final PublicProfile profile;
  final bool blocked;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (profile.age > 0) '${profile.age} yrs',
      if (profile.gender.isNotEmpty) profile.gender,
      if (profile.language.isNotEmpty) profile.language,
    ].join(' · ');
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        children: [
          Row(
            children: [
              RideAvatar(
                initials: profile.initials,
                photoUrl: profile.photoUrl,
                radius: 34,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(details, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: _ProfileMetric(
                  value: profile.rating > 0
                      ? profile.rating.toStringAsFixed(1)
                      : 'New',
                  label: 'Rating',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProfileMetric(
                  value: '${profile.tripCount}',
                  label: 'Trips',
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          FilledButton(
            onPressed: blocked ? null : onMessage,
            child: const Text('Message'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push(
              '${AppRoutes.reportUser}?uid=${Uri.encodeQueryComponent(profile.userId)}&name=${Uri.encodeQueryComponent(profile.displayName)}',
            ),
            child: const Text('Report user'),
          ),
          TextButton(
            onPressed: blocked ? onUnblock : onBlock,
            child: Text(
              blocked ? 'Unblock user' : 'Block user',
              style: TextStyle(
                color: blocked ? AppColors.ink : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
