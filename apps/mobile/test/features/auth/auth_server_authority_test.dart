import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/auth/presentation/auth_screens.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  testWidgets('signup delegates email admission to the backend', (
    tester,
  ) async {
    final auth = _RecordingAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessConfigRepositoryProvider.overrideWithValue(
            MemoryBusinessConfigRepository(localDisplayConfig()),
          ),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SignUpScreen()),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Shohruh');
    await tester.enterText(fields.at(1), 'Alijonov');
    await tester.enterText(fields.at(2), 'shohruxa26@gmail.com');
    await tester.enterText(fields.at(3), 'password1');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();

    expect(auth.lastSignupEmail, 'shohruxa26@gmail.com');
    expect(find.text('Backend validation reached.'), findsOneWidget);
  });

  testWidgets('password reset delegates email admission to the backend', (
    tester,
  ) async {
    final auth = _RecordingAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessConfigRepositoryProvider.overrideWithValue(
            MemoryBusinessConfigRepository(localDisplayConfig()),
          ),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ForgotPasswordScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField),
      'shohruhmirzoalijonov@gmail.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pump();

    expect(auth.lastResetEmail, 'shohruhmirzoalijonov@gmail.com');
    expect(find.text('Backend validation reached.'), findsOneWidget);
  });
}

class _RecordingAuthRepository implements AuthRepository {
  String? lastSignupEmail;
  String? lastResetEmail;

  @override
  AccountUser? get currentUser => null;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    lastSignupEmail = email;
    throw const AppFailure('Backend validation reached.');
  }

  @override
  Future<void> requestPasswordResetCode(String email) async {
    lastResetEmail = email;
    throw const AppFailure('Backend validation reached.');
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<void> resendEmailVerificationCode() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AccountUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> verifyEmailCode(String code) => throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();
}
