import 'package:sidecar/src/core/errors/app_failure.dart';

abstract final class AuthErrorMapper {
  static AppFailure functions({required String code, String? serverMessage}) {
    final message = switch (code) {
      'already-exists' =>
        'An account already exists for this email. Log in or reset your password.',
      'cancelled' => 'The request was cancelled. Please try again.',
      'deadline-exceeded' || 'unavailable' =>
        'The service is temporarily unavailable. Check your connection and try again.',
      'failed-precondition' => _messageOr(
        serverMessage,
        'This request cannot be completed yet. Please check your account and try again.',
      ),
      'invalid-argument' => _messageOr(
        serverMessage,
        'Check the information you entered and try again.',
      ),
      'permission-denied' => _messageOr(
        serverMessage,
        'This email or account is not permitted to use SideCar.',
      ),
      'resource-exhausted' => _messageOr(
        serverMessage,
        'Too many attempts. Please wait before trying again.',
      ),
      'unauthenticated' =>
        'Your session could not be verified. Reopen the app and try again.',
      'aborted' => 'The request was interrupted. Please try again.',
      'not-found' => 'That account could not be found.',
      'internal' ||
      'unknown' ||
      'data-loss' => 'We could not complete that request. Please try again.',
      _ => 'Something went wrong. Please try again.',
    };
    return AppFailure(message, code: code);
  }

  static AppFailure firebaseAuth({
    required String code,
    String? firebaseMessage,
  }) {
    final message = switch (code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'That email or password is not correct.',
      'email-already-in-use' =>
        'An account already exists for this email. Log in or reset your password.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Use 8+ characters with at least one number.',
      'user-disabled' =>
        'This account has been disabled. Contact SideCar support for help.',
      'too-many-requests' =>
        'Too many attempts. Please wait before trying again.',
      'network-request-failed' => 'Check your connection and try again.',
      'operation-not-allowed' =>
        'This sign-in method is temporarily unavailable.',
      'account-exists-with-different-credential' =>
        'This email already uses a different sign-in method.',
      'requires-recent-login' ||
      'user-token-expired' => 'Your session expired. Please sign in again.',
      'credential-already-in-use' =>
        'That sign-in credential is already connected to another account.',
      'app-not-authorized' || 'invalid-api-key' =>
        'This build is not authorized to use authentication. Please update the app.',
      _ => _messageOr(
        firebaseMessage,
        'We could not complete that request. Please try again.',
      ),
    };
    return AppFailure(message, code: code);
  }

  static String _messageOr(String? value, String fallback) {
    final message = value?.trim();
    if (message == null || message.isEmpty) return fallback;
    if (RegExp(r'^[A-Z_ -]+$').hasMatch(message)) return fallback;
    return message;
  }
}
