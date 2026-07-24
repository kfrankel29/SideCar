import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';

abstract interface class AuthRepository {
  Stream<AccountUser?> authStateChanges();
  AccountUser? get currentUser;

  Future<AccountUser?> validateCurrentSession();
  Future<AccountUser> signIn({required String email, required String password});
  Future<AccountUser> signInWithGoogle();

  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  Future<void> resendEmailVerificationCode();
  Future<void> verifyEmailCode(String code);
  Future<void> requestPasswordResetCode(String email);
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  });
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  });
  Future<void> signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw StateError('AuthRepository has not been initialized.'),
);

final authStateProvider = StreamProvider<AccountUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
