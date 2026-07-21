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
        serverMessage: 'Use an approved school email.',
      );

      expect(failure.message, 'Use an approved school email.');
    });

    test('maps temporary backend failures to a retry message', () {
      final failure = AuthErrorMapper.functions(code: 'unavailable');

      expect(failure.message, contains('temporarily unavailable'));
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
