import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/profile/domain/public_profile.dart';

abstract interface class PublicProfileRepository {
  Future<PublicProfile> getProfile(String userId);
}

class UnavailablePublicProfileRepository implements PublicProfileRepository {
  const UnavailablePublicProfileRepository();

  @override
  Future<PublicProfile> getProfile(String userId) async =>
      throw const AppFailure(
        'Profiles are unavailable in this build.',
        code: 'firebase-not-configured',
      );
}

final publicProfileRepositoryProvider = Provider<PublicProfileRepository>(
  (ref) => const UnavailablePublicProfileRepository(),
);
