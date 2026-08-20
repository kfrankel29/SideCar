import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/messaging/domain/conversation_models.dart';
import 'package:sidecar/src/features/messaging/domain/messaging_repository.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class MessageInboxScreen extends ConsumerStatefulWidget {
  const MessageInboxScreen({super.key});

  @override
  ConsumerState<MessageInboxScreen> createState() => _MessageInboxScreenState();
}

class _MessageInboxScreenState extends ConsumerState<MessageInboxScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = ref.watch(currentProfileProvider).value?.userId ?? '';
    final conversations = ref.watch(conversationsProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(conversationsProvider);
          try {
            await ref.read(conversationsProvider.future);
          } on Object {
            // The refreshed provider renders the error and retry action.
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Messages',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search messages…',
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.mutedInk,
                        ),
                        filled: true,
                        fillColor: AppColors.softSurface,
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            conversations.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageLoadError(
                  message: error is AppFailure
                      ? error.message
                      : 'Messages could not be loaded.',
                  onRetry: () => ref.invalidate(conversationsProvider),
                ),
              ),
              data: (items) {
                final query = _search.text.trim().toLowerCase();
                final filtered = items
                    .where(
                      (item) =>
                          query.isEmpty ||
                          item
                              .otherName(currentUid)
                              .toLowerCase()
                              .contains(query) ||
                          item.lastMessage.toLowerCase().contains(query),
                    )
                    .toList(growable: false);
                if (filtered.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Ride conversations will appear here after a seat request.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 82, endIndent: 24),
                  itemBuilder: (context, index) => _ConversationRow(
                    conversation: filtered[index],
                    currentUid: currentUid,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.currentUid,
  });

  final RideConversation conversation;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount(currentUid);
    return InkWell(
      onTap: () => context.push('/messages/${conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unread > 0)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 15, right: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE14942),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 14),
            _MessageAvatar(
              initials: conversation.otherInitials(currentUid),
              photoUrl: conversation.otherPhotoUrl(currentUid),
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                conversation.otherName(currentUid),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (conversation.tripLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 74),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.softSurface,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _compactTripLabel(conversation.tripLabel),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        _inboxTime(conversation.lastMessageAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage.isEmpty
                              ? 'Start the conversation'
                              : conversation.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
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

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _message = TextEditingController();
  bool _sending = false;
  String? _lastReadMessageId;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_markRead);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (_sending || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .sendMessage(widget.conversationId, text);
      _message.clear();
    } on AppFailure catch (error) {
      if (mounted) {
        showAppNotice(context, error.message, kind: AppNoticeKind.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await ref
          .read(messagingRepositoryProvider)
          .markRead(widget.conversationId);
    } on Object {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentProfileProvider).value?.userId ?? '';
    final conversation = ref
        .watch(conversationsProvider)
        .value
        ?.where((item) => item.id == widget.conversationId)
        .firstOrNull;
    final messages = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final otherId = conversation?.otherUserId(uid) ?? '';
    final otherName = conversation?.otherName(uid) ?? 'Conversation';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              name: otherName,
              subtitle: _chatTripSubtitle(conversation),
              initials: conversation?.otherInitials(uid) ?? '',
              photoUrl: conversation?.otherPhotoUrl(uid) ?? '',
              otherUserId: otherId,
              rideId: conversation?.rideId ?? '',
            ),
            const Divider(height: 1),
            Expanded(
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _MessageLoadError(
                  message: error is AppFailure
                      ? error.message
                      : 'Messages could not be loaded.',
                  onRetry: () => ref.invalidate(
                    conversationMessagesProvider(widget.conversationId),
                  ),
                ),
                data: (items) {
                  final latestMessageId = items.firstOrNull?.id;
                  if (latestMessageId != null &&
                      latestMessageId != _lastReadMessageId) {
                    _lastReadMessageId = latestMessageId;
                    scheduleMicrotask(_markRead);
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final showDate =
                          index == items.length - 1 ||
                          !_sameDay(item.createdAt, items[index + 1].createdAt);
                      return Column(
                        children: [
                          if (showDate) ...[
                            Text(
                              _messageDate(item.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 14),
                          ],
                          Row(
                            mainAxisAlignment: item.senderId == uid
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (item.senderId != uid) ...[
                                _MessageAvatar(
                                  initials:
                                      conversation?.otherInitials(uid) ?? '',
                                  photoUrl:
                                      conversation?.otherPhotoUrl(uid) ?? '',
                                  radius: 10,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * .72,
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: item.senderId == uid
                                      ? AppColors.ink
                                      : AppColors.softSurface,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  item.text,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: item.senderId == uid
                                            ? Colors.white
                                            : AppColors.ink,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _Composer(controller: _message, sending: _sending, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _MessageLoadError extends StatelessWidget {
  const _MessageLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.photoUrl,
    required this.otherUserId,
    required this.rideId,
  });

  final String name;
  final String subtitle;
  final String initials;
  final String photoUrl;
  final String otherUserId;
  final String rideId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 7, 12, 10),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: context.pop,
          icon: const FinalDraftBackIcon(size: 22),
        ),
        _MessageAvatar(initials: initials, photoUrl: photoUrl, radius: 14),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: rideId.isEmpty ? null : () => context.push('/rides/$rideId'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (rideId.isNotEmpty)
                          const Icon(Icons.chevron_right_rounded, size: 16),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            final route = value == 'block'
                ? AppRoutes.blockUser
                : AppRoutes.reportUser;
            context.push(
              Uri(
                path: route,
                queryParameters: {'uid': otherUserId, 'name': name},
              ).toString(),
            );
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'report', child: Text('Report user')),
            PopupMenuItem(value: 'block', child: Text('Block user')),
          ],
        ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      10,
      24,
      MediaQuery.paddingOf(context).bottom + 10,
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(
              hintText: 'Message…',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          tooltip: 'Send message',
          onPressed: sending ? null : onSend,
          style: IconButton.styleFrom(backgroundColor: AppColors.ink),
          icon: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
        ),
      ],
    ),
  );
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({
    required this.initials,
    required this.photoUrl,
    required this.radius,
  });

  final String initials;
  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFE7E7E7),
    backgroundImage: photoUrl.isEmpty
        ? null
        : CachedNetworkImageProvider(photoUrl),
    child: photoUrl.isEmpty
        ? Text(
            initials,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.mutedInk),
          )
        : null,
  );
}

String _inboxTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  if (_sameDay(now, value)) return _clock(value);
  if (now.difference(value).inDays < 7) {
    return const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][value.weekday - 1];
  }
  return '${value.month}/${value.day}/${value.year.toString().substring(2)}';
}

String _messageDate(DateTime? value) {
  if (value == null) return '';
  return '${_month(value.month)} ${value.day}, ${value.year} · ${_clock(value)}';
}

String _clock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

bool _sameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

String _compactTripLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '';
  if (normalized.contains('→')) return 'Ride';
  return normalized;
}

String _chatTripSubtitle(RideConversation? conversation) {
  if (conversation == null) return '';
  final route = _shortRoute(conversation.tripLabel);
  final departureAt = conversation.departureAt;
  if (departureAt == null) return route;
  final weekday = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ][departureAt.weekday - 1];
  return "$weekday's trip · $route";
}

String _shortRoute(String value) {
  final parts = value.split('→');
  if (parts.length != 2) return value.trim();
  return '${_shortPlace(parts.first)} → ${_shortPlace(parts.last)}';
}

String _shortPlace(String value) {
  final place = value.trim();
  final lowercase = place.toLowerCase();
  if (lowercase.contains('university of california') &&
      lowercase.contains('santa barbara')) {
    return 'UCSB';
  }
  if (lowercase.contains('isla vista')) return 'IV';
  if (lowercase.contains('caltrain') && lowercase.contains('san mateo')) {
    return 'San Mateo';
  }
  if (place.length <= 18) return place;
  return place.split(',').first.trim();
}
