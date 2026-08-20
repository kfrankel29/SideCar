import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.displayName,
    required this.initials,
    required this.photoUrl,
    this.blockedAt,
  });

  final String id;
  final String displayName;
  final String initials;
  final String photoUrl;
  final DateTime? blockedAt;
}

enum SafetyReportReason {
  unsafeBehavior,
  inappropriateMessages,
  profileOrIdentity,
  paymentOrRide;

  String get title => switch (this) {
    unsafeBehavior => 'Unsafe behavior',
    inappropriateMessages => 'Inappropriate messages',
    profileOrIdentity => 'Profile or identity issue',
    paymentOrRide => 'Payment or ride issue',
  };

  String get description => switch (this) {
    unsafeBehavior => 'Driving, threats, or harassment',
    inappropriateMessages => 'Unwanted or offensive communication',
    profileOrIdentity => 'False details or impersonation',
    paymentOrRide => 'A problem connected to a booking',
  };
}

abstract interface class SafetyRepository {
  Future<List<BlockedUser>> listBlockedUsers();
  Future<bool> isBlocked(String targetUserId);
  Future<void> blockUser(String targetUserId);
  Future<void> unblockUser(String targetUserId);
  Future<void> reportUser({
    required String targetUserId,
    required SafetyReportReason reason,
    String details = '',
  });
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => throw StateError('SafetyRepository has not been initialized.'),
);

final blockedUsersProvider = FutureProvider<List<BlockedUser>>(
  (ref) => ref.watch(safetyRepositoryProvider).listBlockedUsers(),
);
