import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/features/auth/data/firebase_auth_repository.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/auth/presentation/auth_screens.dart';
import 'package:sidecar/src/features/profile/data/firebase_profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/presentation/profile_screens.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final screens = <String, Widget>{
    'welcome': const WelcomeScreen(),
    'login': const LoginScreen(),
    'sign up': const SignUpScreen(),
    'email verification': const EmailVerificationScreen(email: 'maya@ucsb.edu'),
    'forgot password': const ForgotPasswordScreen(),
    'reset code': const PasswordResetCodeScreen(email: 'maya@ucsb.edu'),
    'new password': const NewPasswordScreen(
      email: 'maya@ucsb.edu',
      resetToken: 'test-token',
    ),
    'password reset complete': const PasswordResetCompleteScreen(),
    'profile setup': const ProfileSetupScreen(),
    'photo permission': const PhotoPermissionScreen(),
    'welcome aboard': const OnboardedScreen(),
    'profile gate': const ProfileGateScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} fits the 375 x 812 design viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessConfigRepositoryProvider.overrideWithValue(
              MemoryBusinessConfigRepository(localDisplayConfig()),
            ),
            authRepositoryProvider.overrideWithValue(
              const UnavailableAuthRepository(),
            ),
            profileRepositoryProvider.overrideWithValue(
              const UnavailableProfileRepository(),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: entry.value),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  }
}
