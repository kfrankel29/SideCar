import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/messaging/domain/conversation_models.dart';
import 'package:sidecar/src/features/messaging/domain/messaging_repository.dart';

class FirebaseMessagingRepository implements MessagingRepository {
  FirebaseMessagingRepository(this._auth, this._firestore, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppFailure('Please sign in again.');
    return uid;
  }

  @override
  Stream<List<RideConversation>> watchConversations() {
    final uid = _uid;
    return _firestore
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final conversations = snapshot.docs
              .map(RideConversation.fromSnapshot)
              .where((conversation) => !conversation.isHiddenFor(uid))
              .toList();
          conversations.sort(
            (a, b) =>
                (b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                    ),
          );
          final byMember = <String, RideConversation>{};
          for (final conversation in conversations) {
            final otherUserId = conversation.otherUserId(uid);
            if (otherUserId.isNotEmpty) {
              byMember.putIfAbsent(otherUserId, () => conversation);
            }
          }
          return byMember.values.toList(growable: false);
        });
  }

  @override
  Stream<List<ConversationMessage>> watchMessages(String conversationId) =>
      _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(ConversationMessage.fromSnapshot)
                .toList(growable: false),
          );

  @override
  Future<RideConversation> openBookingConversation(String bookingId) async {
    final data = await _call('openBookingConversation', {
      'bookingId': bookingId,
    });
    final conversationId = data['conversationId'] as String? ?? '';
    if (conversationId.isEmpty) {
      throw const AppFailure('That conversation could not be opened.');
    }
    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();
    return RideConversation.fromSnapshot(snapshot);
  }

  @override
  Future<RideConversation> openDirectConversation(String userId) async {
    final data = await _call('openDirectConversation', {'userId': userId});
    final conversationId = data['conversationId'] as String? ?? '';
    if (conversationId.isEmpty) {
      throw const AppFailure('That conversation could not be opened.');
    }
    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .get();
    return RideConversation.fromSnapshot(snapshot);
  }

  @override
  Future<void> sendMessage(String conversationId, String text) async {
    await _call('sendRideMessage', {
      'conversationId': conversationId,
      'text': text.trim(),
    });
  }

  @override
  Future<void> markRead(String conversationId) async {
    await _call('markConversationRead', {'conversationId': conversationId});
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> payload,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(payload)
          .timeout(const Duration(seconds: 20));
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw AppFailure(error.message ?? 'Messaging could not be updated.');
    } on TimeoutException {
      throw const AppFailure('That took too long. Please try again.');
    }
  }
}
