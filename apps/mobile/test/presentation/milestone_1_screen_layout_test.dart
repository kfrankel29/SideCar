import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/features/auth/data/firebase_auth_repository.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/auth/presentation/auth_screens.dart';
import 'package:sidecar/src/features/profile/data/firebase_profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/profile/presentation/profile_screens.dart';
import 'package:sidecar/src/routing/app_router.dart';
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

  testWidgets('profile setup blocks blank required fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const UnavailableAuthRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(
            const UnavailableProfileRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfileSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Enter a valid age'), findsOneWidget);
  });

  testWidgets('profile photo offers camera and photo library', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const UnavailableAuthRepository(),
          ),
          profileRepositoryProvider.overrideWithValue(
            const UnavailableProfileRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfileSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SC'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from library'), findsOneWidget);
  });

  testWidgets('profile setup requires a photo before continuing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(const _SignedInAuth()),
          profileRepositoryProvider.overrideWithValue(
            _MemoryProfileRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfileSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '20');
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();

    expect(find.text('Add a profile photo to continue.'), findsOneWidget);
  });

  testWidgets('selected spoken language saves and profile setup completes', (
    tester,
  ) async {
    final repository = _MemoryProfileRepository(
      profile: _MemoryProfileRepository.completeProfile,
    );
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboarded,
          builder: (_, _) => const Scaffold(body: Text('Profile saved')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(const _SignedInAuth()),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spanish').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(repository.profile?.language, 'Spanish');
    expect(find.text('Profile saved'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('role selection matches the Final Draft copy', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(const _SignedInAuth()),
          profileRepositoryProvider.overrideWithValue(
            _MemoryProfileRepository(
              profile: _MemoryProfileRepository.completeProfile,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardedScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Welcome aboard, Maya'), findsOneWidget);
    expect(
      find.text("You're all set!\nHow will you mostly use SideCar?"),
      findsOneWidget,
    );
    expect(find.text('Book a ride'), findsOneWidget);
    expect(find.text('Post a ride'), findsOneWidget);
  });
}

class _SignedInAuth implements AuthRepository {
  const _SignedInAuth();

  static const user = AccountUser(
    id: 'user-1',
    email: 'maya@ucsb.edu',
    emailVerified: true,
  );

  @override
  AccountUser? get currentUser => user;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(user);

  @override
  Future<AccountUser?> validateCurrentSession() async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AccountUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> resendEmailVerificationCode() => throw UnimplementedError();

  @override
  Future<void> verifyEmailCode(String code) => throw UnimplementedError();

  @override
  Future<void> requestPasswordResetCode(String email) =>
      throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();

  @override
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) => throw UnimplementedError();
}

class _MemoryProfileRepository implements ProfileRepository {
  _MemoryProfileRepository({this.profile});

  static const completeProfile = UserProfile(
    userId: 'user-1',
    firstName: 'Maya',
    lastName: 'Chen',
    school: 'UC Santa Barbara',
    age: 20,
    gender: 'Female',
    language: 'English',
    photoUrl: 'https://example.test/maya.jpg',
  );

  UserProfile? profile;

  @override
  Future<UserProfile?> loadCurrentProfile() async => profile;

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);

  @override
  Future<void> saveProfile(UserProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> setPrimaryRole(PrimaryRole role) async {
    profile = profile?.copyWith(primaryRole: role);
  }

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://example.test/maya.jpg';
}
