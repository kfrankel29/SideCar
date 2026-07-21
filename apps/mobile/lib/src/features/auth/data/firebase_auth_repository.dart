import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/auth/data/auth_error_mapper.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  Future<void>? _googleInitialization;

  static const _googleClientId = String.fromEnvironment(
    'SIDECAR_GOOGLE_IOS_CLIENT_ID',
  );
  static const _googleServerClientId = String.fromEnvironment(
    'SIDECAR_GOOGLE_SERVER_CLIENT_ID',
  );

  @override
  AccountUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AccountUser?> authStateChanges() {
    return _auth.userChanges().map(_mapUser);
  }

  @override
  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    var recoveringExistingAccount = false;
    try {
      try {
        await _functions.httpsCallable('createStudentAccount').call({
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'email': normalizedEmail,
          'password': password,
        });
      } on FirebaseFunctionsException catch (error) {
        if (error.code != 'already-exists') rethrow;
        recoveringExistingAccount = true;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      if (recoveringExistingAccount &&
          credential.user?.emailVerified == false) {
        try {
          await _functions.httpsCallable('requestEmailVerificationCode').call({
            'firstName': firstName.trim(),
            'lastName': lastName.trim(),
          });
        } on FirebaseFunctionsException catch (error) {
          if (error.code != 'resource-exhausted') rethrow;
        }
      }
      return _requireUser(credential.user);
    } on FirebaseAuthException catch (error) {
      if (recoveringExistingAccount &&
          const {
            'invalid-credential',
            'wrong-password',
            'user-not-found',
          }.contains(error.code)) {
        throw const AppFailure(
          'An account already exists for this email. Log in or reset your password.',
          code: 'already-exists',
        );
      }
      throw _mapFailure(error);
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return _requireUser(credential.user);
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<AccountUser> signInWithGoogle() async {
    try {
      await _initializeGoogleSignIn();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      try {
        await _functions.httpsCallable('completeGoogleStudentSignIn').call();
      } on Object {
        await _auth.signOut();
        rethrow;
      }
      await result.user?.reload();
      return _requireUser(_auth.currentUser);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AppFailure('Google sign-in was cancelled.');
      }
      throw const AppFailure('Google sign-in could not be completed.');
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  Future<void> _initializeGoogleSignIn() {
    return _googleInitialization ??= GoogleSignIn.instance.initialize(
      clientId: _googleClientId.isEmpty ? null : _googleClientId,
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
    );
  }

  @override
  Future<void> resendEmailVerificationCode() async {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please sign in again.');
    try {
      await _functions.httpsCallable('requestEmailVerificationCode').call();
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> verifyEmailCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppFailure('Please sign in again.');
    try {
      await _functions.httpsCallable('verifyEmailCode').call({'code': code});
      await user.reload();
      await user.getIdToken(true);
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> requestPasswordResetCode(String email) async {
    try {
      await _functions.httpsCallable('requestPasswordResetCode').call({
        'email': email.trim().toLowerCase(),
      });
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('verifyPasswordResetCode')
          .call({'email': email.trim().toLowerCase(), 'code': code});
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['resetToken'] as String;
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _functions.httpsCallable('completePasswordReset').call({
        'email': email.trim().toLowerCase(),
        'resetToken': resetToken,
        'newPassword': newPassword,
      });
    } on Object catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AccountUser _requireUser(User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) {
      throw const AppFailure('Authentication did not complete.');
    }
    return mapped;
  }

  AccountUser? _mapUser(User? user) {
    final email = user?.email;
    if (user == null || email == null) return null;
    return AccountUser(
      id: user.uid,
      email: email,
      emailVerified: user.emailVerified,
    );
  }

  AppFailure _mapFailure(Object error) {
    if (error is AppFailure) return error;
    if (error is FirebaseFunctionsException) {
      return AuthErrorMapper.functions(
        code: error.code,
        serverMessage: error.message,
      );
    }
    if (error is FirebaseAuthException) {
      return AuthErrorMapper.firebaseAuth(
        code: error.code,
        firebaseMessage: error.message,
      );
    }
    return const AppFailure('Something went wrong. Please try again.');
  }
}

class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  Never _notReady() {
    throw const AppFailure(
      'Firebase is not configured for this build yet.',
      code: 'firebase-not-configured',
    );
  }

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(null);

  @override
  AccountUser? get currentUser => null;

  @override
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async => _notReady();

  @override
  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async => _notReady();

  @override
  Future<void> requestPasswordResetCode(String email) async => _notReady();

  @override
  Future<void> resendEmailVerificationCode() async => _notReady();

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) async => _notReady();

  @override
  Future<AccountUser> signInWithGoogle() async => _notReady();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> verifyEmailCode(String code) async => _notReady();

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async => _notReady();
}
