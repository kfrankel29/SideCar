import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/messaging/domain/conversation_models.dart';

abstract interface class MessagingRepository {
  Stream<List<RideConversation>> watchConversations();
  Stream<List<ConversationMessage>> watchMessages(String conversationId);
  Future<RideConversation> openBookingConversation(String bookingId);
  Future<RideConversation> openDirectConversation(String userId);
  Future<void> sendMessage(String conversationId, String text);
  Future<void> markRead(String conversationId);
}

class UnavailableMessagingRepository implements MessagingRepository {
  const UnavailableMessagingRepository();

  Never _unavailable() => throw const AppFailure(
    'Messaging is unavailable in this build.',
    code: 'firebase-not-configured',
  );

  @override
  Future<void> markRead(String conversationId) async => _unavailable();

  @override
  Future<RideConversation> openBookingConversation(String bookingId) async =>
      _unavailable();

  @override
  Future<RideConversation> openDirectConversation(String userId) async =>
      _unavailable();

  @override
  Future<void> sendMessage(String conversationId, String text) async =>
      _unavailable();

  @override
  Stream<List<RideConversation>> watchConversations() => const Stream.empty();

  @override
  Stream<List<ConversationMessage>> watchMessages(String conversationId) =>
      const Stream.empty();
}

final messagingRepositoryProvider = Provider<MessagingRepository>(
  (ref) => const UnavailableMessagingRepository(),
);

final conversationsProvider = StreamProvider<List<RideConversation>>(
  (ref) => ref.watch(messagingRepositoryProvider).watchConversations(),
);

final conversationMessagesProvider =
    StreamProvider.family<List<ConversationMessage>, String>(
      (ref, conversationId) =>
          ref.watch(messagingRepositoryProvider).watchMessages(conversationId),
    );
