import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/auth/presentation/auth_screens.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  testWidgets('verification back returns to signup with its fields intact', (
    tester,
  ) async {
    final auth = _NavigationAuthRepository();
    final router = _router(AppRoutes.signUp);
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router, auth));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Maya');
    await tester.enterText(fields.at(1), 'Chen');
    await tester.enterText(fields.at(2), 'maya@ucsb.edu');
    await tester.enterText(fields.at(3), 'password1');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await _pumpNavigation(tester);

    expect(find.text('Check your inbox'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await _pumpNavigation(tester);

    expect(find.text('Create an account'), findsOneWidget);
    expect(_fieldText(tester, 0), 'Maya');
    expect(_fieldText(tester, 1), 'Chen');
    expect(_fieldText(tester, 2), 'maya@ucsb.edu');
    expect(_fieldText(tester, 3), 'password1');
    expect(auth.signOutCount, 1);
  });

  testWidgets('signup back returns one step to login without clearing login', (
    tester,
  ) async {
    final auth = _NavigationAuthRepository();
    final router = _router(AppRoutes.login);
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router, auth));

    await tester.enterText(find.byType(TextFormField).at(0), 'maya@ucsb.edu');
    await tester.enterText(find.byType(TextFormField).at(1), 'password1');
    await tester.tap(find.text('New here? Sign up'));
    await _pumpNavigation(tester);

    expect(find.text('Create an account'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await _pumpNavigation(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(_fieldText(tester, 0), 'maya@ucsb.edu');
    expect(_fieldText(tester, 1), 'password1');
  });

  testWidgets('reset code back returns to the entered reset email', (
    tester,
  ) async {
    final auth = _NavigationAuthRepository();
    final router = _router(AppRoutes.forgotPassword);
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router, auth));

    await tester.enterText(find.byType(TextFormField), 'maya@ucsb.edu');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await _pumpNavigation(tester);

    expect(find.text('Check your inbox'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await _pumpNavigation(tester);

    expect(find.text('Reset your password'), findsOneWidget);
    expect(_fieldText(tester, 0), 'maya@ucsb.edu');
  });
}

Future<void> _pumpNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Widget _testApp(GoRouter router, AuthRepository auth) {
  return ProviderScope(
    overrides: [
      businessConfigRepositoryProvider.overrideWithValue(
        MemoryBusinessConfigRepository(localDisplayConfig()),
      ),
      authRepositoryProvider.overrideWithValue(auth),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

GoRouter _router(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, state) => EmailVerificationScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetCode,
        builder: (_, state) => PasswordResetCodeScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
    ],
  );
}

String _fieldText(WidgetTester tester, int index) {
  return tester
          .widget<TextFormField>(find.byType(TextFormField).at(index))
          .controller
          ?.text ??
      '';
}

class _NavigationAuthRepository implements AuthRepository {
  int signOutCount = 0;

  @override
  AccountUser? get currentUser => null;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AccountUser?> validateCurrentSession() async => null;

  @override
  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    return AccountUser(id: 'user-1', email: email, emailVerified: false);
  }

  @override
  Future<void> requestPasswordResetCode(String email) async {}

  @override
  Future<void> signOut() async {
    signOutCount += 1;
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> resendEmailVerificationCode() {
    throw UnimplementedError();
  }

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AccountUser> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> verifyEmailCode(String code) {
    throw UnimplementedError();
  }

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) {
    throw UnimplementedError();
  }
}
