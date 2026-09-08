import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/auth/data/auth_error_mapper.dart';

abstract interface class AccountSecurityRepository {
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> deleteAccount({required String confirmation});
}

final accountSecurityRepositoryProvider = Provider<AccountSecurityRepository>((
  ref,
) {
  if (Firebase.apps.isEmpty) {
    return const UnavailableAccountSecurityRepository();
  }
  return FirebaseAccountSecurityRepository(
    FirebaseAuth.instance,
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  );
});

class FirebaseAccountSecurityRepository implements AccountSecurityRepository {
  const FirebaseAccountSecurityRepository(this._auth, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AppFailure('Please sign in again.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
      await user.updatePassword(newPassword);
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw AuthErrorMapper.firebaseAuth(
        code: error.code,
        firebaseMessage: error.message,
      );
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure('Password could not be updated. Try again.');
    }
  }

  @override
  Future<void> deleteAccount({required String confirmation}) async {
    try {
      await _functions.httpsCallable('requestAccountDeletion').call<void>({
        'confirmation': confirmation,
      });
      await _auth.signOut();
    } on FirebaseFunctionsException catch (error) {
      throw AuthErrorMapper.functions(
        code: error.code,
        serverMessage: error.message,
      );
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure('Account deletion could not be completed.');
    }
  }
}

class UnavailableAccountSecurityRepository
    implements AccountSecurityRepository {
  const UnavailableAccountSecurityRepository();

  Never _notReady() => throw const AppFailure(
    'We can’t connect right now. Install the latest build and try again.',
  );

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => _notReady();

  @override
  Future<void> deleteAccount({required String confirmation}) async =>
      _notReady();
}
