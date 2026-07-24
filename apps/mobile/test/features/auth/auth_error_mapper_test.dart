import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/auth/data/auth_error_mapper.dart';

void main() {
  group('AuthErrorMapper.functions', () {
    test('never exposes a raw INTERNAL response', () {
      final failure = AuthErrorMapper.functions(
        code: 'internal',
        serverMessage: 'INTERNAL',
      );

      expect(
        failure.message,
        'We could not complete that request. Please try again.',
      );
    });

    test('keeps actionable server validation messages', () {
      final failure = AuthErrorMapper.functions(
        code: 'permission-denied',
        serverMessage: 'Students only — ucsb.edu email required',
      );

      expect(failure.message, 'Students only — ucsb.edu email required');
    });

    test('does not show the old reopen-app session error', () {
      final failure = AuthErrorMapper.functions(
        code: 'unauthenticated',
        serverMessage: 'Unauthenticated',
      );

      expect(
        failure.message,
        'We could not verify this request. Please try again.',
      );
      expect(failure.message, isNot(contains('Reopen the app')));
    });

    test('maps temporary backend failures to a retry message', () {
      final failure = AuthErrorMapper.functions(code: 'unavailable');

      expect(failure.message, contains('temporarily unavailable'));
    });

    test('shows a clear missing-account reset error', () {
      final failure = AuthErrorMapper.functions(
        code: 'not-found',
        serverMessage: 'No account was found for this email.',
      );

      expect(failure.message, 'That account could not be found.');
    });
  });

  group('AuthErrorMapper.firebaseAuth', () {
    test('does not reveal whether a login email exists', () {
      final missing = AuthErrorMapper.firebaseAuth(code: 'user-not-found');
      final wrong = AuthErrorMapper.firebaseAuth(code: 'wrong-password');

      expect(missing.message, wrong.message);
    });

    test('maps configuration failures without exposing Firebase details', () {
      final failure = AuthErrorMapper.firebaseAuth(code: 'app-not-authorized');

      expect(failure.message, contains('not authorized'));
    });
  });
}
