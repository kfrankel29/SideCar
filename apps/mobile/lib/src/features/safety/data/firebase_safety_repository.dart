import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';

class FirebaseSafetyRepository implements SafetyRepository {
  FirebaseSafetyRepository(this._functions);

  final FirebaseFunctions _functions;
  static const _timeout = Duration(seconds: 20);

  @override
  Future<List<BlockedUser>> listBlockedUsers() async {
    final data = await _call('listBlockedUsers', const {});
    final users = data['users'];
    if (users is! List) return const [];
    return users
        .whereType<Map>()
        .map((item) {
          final value = Map<String, dynamic>.from(item);
          return BlockedUser(
            id: value['id'] as String? ?? '',
            displayName: value['displayName'] as String? ?? 'SideCar member',
            initials: value['initials'] as String? ?? '',
            photoUrl: value['photoUrl'] as String? ?? '',
            blockedAt: switch (value['blockedAt']) {
              final num milliseconds => DateTime.fromMillisecondsSinceEpoch(
                milliseconds.toInt(),
              ),
              _ => null,
            },
          );
        })
        .where((user) => user.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<bool> isBlocked(String targetUserId) async {
    final data = await _call('getBlockStatus', {'targetUserId': targetUserId});
    return data['blocked'] == true;
  }

  @override
  Future<void> blockUser(String targetUserId) async {
    await _call('blockUser', {'targetUserId': targetUserId});
  }

  @override
  Future<void> unblockUser(String targetUserId) async {
    await _call('unblockUser', {'targetUserId': targetUserId});
  }

  @override
  Future<void> reportUser({
    required String targetUserId,
    required SafetyReportReason reason,
    String details = '',
  }) async {
    await _call('reportUser', {
      'targetUserId': targetUserId,
      'reason': reason.name,
      'details': details.trim(),
    });
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>(data)
          .timeout(_timeout);
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw AppFailure(
        error.message ?? 'We could not complete this safety action.',
        code: error.code,
      );
    } on TimeoutException {
      throw const AppFailure(
        'This action took too long. Check your connection and try again.',
      );
    }
  }
}

class UnavailableSafetyRepository implements SafetyRepository {
  const UnavailableSafetyRepository();

  Never _notReady() => throw const AppFailure(
    'Safety services are unavailable in this build.',
    code: 'firebase-not-configured',
  );

  @override
  Future<List<BlockedUser>> listBlockedUsers() async => _notReady();

  @override
  Future<bool> isBlocked(String targetUserId) async => _notReady();

  @override
  Future<void> blockUser(String targetUserId) async => _notReady();

  @override
  Future<void> unblockUser(String targetUserId) async => _notReady();

  @override
  Future<void> reportUser({
    required String targetUserId,
    required SafetyReportReason reason,
    String details = '',
  }) async => _notReady();
}
