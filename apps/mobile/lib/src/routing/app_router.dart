import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/features/auth/presentation/auth_screens.dart';
import 'package:sidecar/src/features/diagnostics/presentation/config_diagnostics_screen.dart';
import 'package:sidecar/src/features/profile/presentation/profile_screens.dart';

abstract final class AppRoutes {
  static const opening = '/opening';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetCode = '/reset-code';
  static const newPassword = '/new-password';
  static const passwordResetComplete = '/password-reset-complete';
  static const profile = '/profile';
  static const photoPermission = '/photo-permission';
  static const onboarded = '/onboarded';
  static const profileGate = '/profile-gate';
  static const diagnostics = '/diagnostics/config';

  static String get initialLocation {
    const buildRoute = String.fromEnvironment('SIDECAR_INITIAL_ROUTE');
    if (buildRoute.isNotEmpty) return buildRoute;
    if (kDebugMode) {
      final runtimeRoute = Platform.environment['SIDECAR_INITIAL_ROUTE'];
      if (runtimeRoute != null && runtimeRoute.isNotEmpty) return runtimeRoute;
    }
    return opening;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.opening,
        builder: (_, state) => OpeningScreen(
          autoContinue:
              !(kDebugMode && state.uri.queryParameters['visualQa'] == 'true'),
        ),
      ),
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
      GoRoute(
        path: AppRoutes.newPassword,
        builder: (_, state) => NewPasswordScreen(
          email: state.uri.queryParameters['email'] ?? '',
          resetToken: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.passwordResetComplete,
        builder: (_, _) => const PasswordResetCompleteScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.photoPermission,
        builder: (_, _) => const PhotoPermissionScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarded,
        builder: (_, _) => const OnboardedScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileGate,
        builder: (_, _) => const ProfileGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        builder: (_, _) => const ConfigDiagnosticsScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
