import 'package:cloud_firestore/cloud_firestore.dart';

class RideConversation {
  const RideConversation({
    required this.id,
    required this.bookingId,
    required this.rideId,
    required this.participantIds,
    required this.participantNames,
    required this.participantInitials,
    required this.participantPhotoUrls,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCounts,
    required this.hiddenFor,
    required this.tripLabel,
    this.departureAt,
  });

  factory RideConversation.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return RideConversation(
      id: snapshot.id,
      bookingId: data['bookingId'] as String? ?? snapshot.id,
      rideId: data['rideId'] as String? ?? '',
      participantIds: _stringList(data['participantIds']),
      participantNames: _stringMap(data['participantNames']),
      participantInitials: _stringMap(data['participantInitials']),
      participantPhotoUrls: _stringMap(data['participantPhotoUrls']),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCounts: _intMap(data['unreadCounts']),
      hiddenFor: _boolMap(data['hiddenFor']),
      tripLabel: data['tripLabel'] as String? ?? '',
      departureAt: _dateTime(data['departureAt']),
    );
  }

  final String id;
  final String bookingId;
  final String rideId;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String> participantInitials;
  final Map<String, String> participantPhotoUrls;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts;
  final Map<String, bool> hiddenFor;
  final String tripLabel;
  final DateTime? departureAt;

  String otherUserId(String currentUserId) =>
      participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');

  String otherName(String currentUserId) =>
      participantNames[otherUserId(currentUserId)] ?? 'SideCar member';

  String otherInitials(String currentUserId) =>
      participantInitials[otherUserId(currentUserId)] ?? '';

  String otherPhotoUrl(String currentUserId) =>
      participantPhotoUrls[otherUserId(currentUserId)] ?? '';

  int unreadCount(String currentUserId) => unreadCounts[currentUserId] ?? 0;

  bool isHiddenFor(String currentUserId) => hiddenFor[currentUserId] ?? false;
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory ConversationMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ConversationMessage(
      id: snapshot.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
}

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry('$key', item is String ? item : ''));
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, item) => MapEntry('$key', item is num ? item.round() : 0),
  );
}

Map<String, bool> _boolMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry('$key', item is bool && item));
}

DateTime? _dateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
