import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';

abstract interface class ProfileRepository {
  Stream<UserProfile?> watchCurrentProfile();
  Future<UserProfile?> loadCurrentProfile();
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  });
  Future<void> saveProfile(UserProfile profile);
  Future<void> setPrimaryRole(PrimaryRole role);
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => throw StateError('ProfileRepository has not been initialized.'),
);

final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchCurrentProfile();
});
