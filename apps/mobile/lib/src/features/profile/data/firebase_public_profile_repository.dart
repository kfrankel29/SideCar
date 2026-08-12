import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/profile/domain/public_profile.dart';
import 'package:sidecar/src/features/profile/domain/public_profile_repository.dart';

class FirebasePublicProfileRepository implements PublicProfileRepository {
  FirebasePublicProfileRepository(this._functions);

  final FirebaseFunctions _functions;
  final _cache = <String, PublicProfile>{};

  @override
  Future<PublicProfile> getProfile(String userId) async {
    final cached = _cache[userId];
    if (cached != null) return cached;
    try {
      final result = await _functions
          .httpsCallable('getPublicProfile')
          .call<Map<String, dynamic>>({'userId': userId})
          .timeout(const Duration(seconds: 15));
      final value = result.data['profile'];
      final json = value is Map<String, dynamic>
          ? value
          : value is Map
          ? value.map((key, item) => MapEntry('$key', item))
          : <String, dynamic>{};
      final profile = PublicProfile.fromJson(json);
      _cache[userId] = profile;
      return profile;
    } on FirebaseFunctionsException catch (error) {
      throw AppFailure(error.message ?? 'That profile could not be loaded.');
    } on TimeoutException {
      throw const AppFailure('That profile took too long to load. Try again.');
    }
  }
}
