import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';

class FirebaseSafetyRepository implements SafetyRepository {
  FirebaseSafetyRepository(this._functions);

  final FirebaseFunctions _functions;
  static const _timeout = Duration(seconds: 20);

  @override
  Future<void> blockUser(String targetUserId) async {
    await _call('blockUser', {'targetUserId': targetUserId});
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

  Future<void> _call(String name, Map<String, Object?> data) async {
    try {
      await _functions.httpsCallable(name).call<void>(data).timeout(_timeout);
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
  Future<void> blockUser(String targetUserId) async => _notReady();

  @override
  Future<void> reportUser({
    required String targetUserId,
    required SafetyReportReason reason,
    String details = '',
  }) async => _notReady();
}
