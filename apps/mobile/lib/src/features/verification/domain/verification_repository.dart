import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';

abstract interface class VerificationRepository {
  Stream<VerificationSummary> watchCurrentVerification();
  Future<VerificationSummary> loadCurrentVerification();
  Future<Uri?> createIdentityVerificationSession();
  Future<String> uploadVehiclePhoto({
    required Uint8List bytes,
    required String contentType,
  });
  Future<void> saveVehicle(VehicleProfile vehicle);
  Future<void> verifyInsuranceForTesting();
  Future<void> submitInsuranceDocument({
    required Uint8List bytes,
    required String contentType,
  });
}

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => throw StateError('VerificationRepository has not been initialized.'),
);

final currentVerificationProvider = StreamProvider<VerificationSummary>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(verificationRepositoryProvider).watchCurrentVerification();
});
