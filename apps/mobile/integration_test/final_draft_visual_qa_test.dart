import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/app.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/auth/presentation/auth_screens.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the Milestone 1 and 2 Final Draft routes', (
    tester,
  ) async {
    final profileRepository = _QaProfileRepository();
    final verificationRepository = _QaVerificationRepository();
    runApp(
      ProviderScope(
        overrides: [
          businessConfigRepositoryProvider.overrideWithValue(
            MemoryBusinessConfigRepository(localDisplayConfig()),
          ),
          authRepositoryProvider.overrideWithValue(const _QaAuthRepository()),
          profileRepositoryProvider.overrideWithValue(profileRepository),
          verificationRepositoryProvider.overrideWithValue(
            verificationRepository,
          ),
          safetyRepositoryProvider.overrideWithValue(_QaSafetyRepository()),
        ],
        child: const SideCarApp(),
      ),
    );
    await tester.pumpAndSettle();

    final appContext = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(appContext);
    final router = container.read(appRouterProvider);

    const routes = <String, String>{
      'opening': '${AppRoutes.opening}?visualQa=true',
      'welcome': AppRoutes.welcome,
      'login': AppRoutes.login,
      'sign-up': AppRoutes.signUp,
      'verify-email': '${AppRoutes.verifyEmail}?email=maya@ucsb.edu',
      'forgot-password': AppRoutes.forgotPassword,
      'reset-code': '${AppRoutes.resetCode}?email=maya@ucsb.edu',
      'new-password':
          '${AppRoutes.newPassword}?email=maya@ucsb.edu&token=preview',
      'password-reset-complete': AppRoutes.passwordResetComplete,
      'profile': AppRoutes.profile,
      'photo-permission': AppRoutes.photoPermission,
      'onboarded': AppRoutes.onboarded,
      'profile-gate': AppRoutes.profileGate,
      'verification-hub': AppRoutes.verification,
      'identity-verification': AppRoutes.identityVerification,
      'driver-license': AppRoutes.driverLicense,
      'vehicle-profile': AppRoutes.vehicleProfile,
      'insurance-verification': AppRoutes.insuranceVerification,
      'insurance-fallback': AppRoutes.insuranceFallback,
      'verification-complete': AppRoutes.verificationComplete,
      'safety-tools': AppRoutes.safetyTools,
      'block-user': '${AppRoutes.blockUser}?uid=visual-target&name=Jordan',
      'report-user': '${AppRoutes.reportUser}?uid=visual-target&name=Jordan',
    };

    for (final entry in routes.entries) {
      verificationRepository.summary = _verificationStateFor(entry.key);
      container.invalidate(currentVerificationProvider);
      router.go(entry.value);
      if (entry.key == 'opening') {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      } else {
        await tester.pumpAndSettle();
      }
      await _applyFinalDraftState(tester, entry.key);
      expect(find.textContaining('Milestone'), findsNothing);
      expect(find.textContaining('later approved'), findsNothing);
      await binding.takeScreenshot(entry.key);
    }
  });
}

VerificationSummary _verificationStateFor(String screen) {
  const vehicle = VehicleProfile(
    year: 2021,
    make: 'Honda',
    model: 'CR-V',
    color: 'White',
    licensePlate: '8ABC123',
    photoUrl: 'visual-qa-vehicle',
  );
  return switch (screen) {
    'insurance-fallback' => const VerificationSummary(
      identity: VerificationStatus.verified,
      insurance: VerificationStatus.requiresAction,
      vehicle: vehicle,
    ),
    'verification-complete' => const VerificationSummary(
      identity: VerificationStatus.verified,
      insurance: VerificationStatus.verified,
      vehicle: vehicle,
    ),
    'vehicle-profile' || 'insurance-verification' => const VerificationSummary(
      identity: VerificationStatus.verified,
      vehicle: vehicle,
    ),
    _ => const VerificationSummary(),
  };
}

Future<void> _applyFinalDraftState(WidgetTester tester, String screen) async {
  if (screen == 'opening') return;
  final fields = find.byType(TextFormField);
  switch (screen) {
    case 'login':
      await tester.enterText(fields.at(0), 'maya@ucsb.edu');
      await tester.enterText(fields.at(1), 'password1');
    case 'sign-up':
      await tester.enterText(fields.at(0), 'Maya');
      await tester.enterText(fields.at(1), 'Chen');
      await tester.enterText(fields.at(2), 'maya@ucsb.edu');
    case 'verify-email':
    case 'reset-code':
      await tester.tap(find.byType(OtpCodeInput));
      tester.testTextInput.enterText('417');
      await tester.pump();
    case 'new-password':
      await tester.enterText(fields.at(0), 'password1');
      await tester.enterText(fields.at(1), 'password1');
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

class _QaAuthRepository implements AuthRepository {
  const _QaAuthRepository();

  static const user = AccountUser(
    id: 'visual-qa',
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
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {}

  @override
  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async => user;

  @override
  Future<void> requestPasswordResetCode(String email) async {}

  @override
  Future<void> resendEmailVerificationCode() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) async => user;

  @override
  Future<AccountUser> signInWithGoogle() async => user;

  @override
  Future<void> verifyEmailCode(String code) async {}

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async => 'visual-qa-token';
}

class _QaProfileRepository implements ProfileRepository {
  UserProfile profile = const UserProfile(
    userId: 'visual-qa',
    firstName: 'Maya',
    lastName: 'Chen',
    school: 'UC Santa Barbara',
    age: 20,
    gender: 'Female',
    language: 'English',
    photoUrl: 'visual-qa-photo',
    primaryRole: PrimaryRole.driver,
  );

  @override
  Future<UserProfile?> loadCurrentProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> setPrimaryRole(PrimaryRole role) async {
    profile = profile.copyWith(primaryRole: role);
  }

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => 'visual-qa-photo';

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);
}

class _QaVerificationRepository implements VerificationRepository {
  VerificationSummary summary = const VerificationSummary();

  @override
  Future<Uri> createIdentityVerificationSession() async =>
      Uri.parse('https://example.com/identity');

  @override
  Future<VerificationSummary> loadCurrentVerification() async => summary;

  @override
  Future<void> saveVehicle(VehicleProfile vehicle) async {}

  @override
  Future<void> submitInsuranceDocument({
    required Uint8List bytes,
    required String contentType,
  }) async {}

  @override
  Future<String> uploadVehiclePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => 'visual-qa-vehicle';

  @override
  Stream<VerificationSummary> watchCurrentVerification() =>
      Stream.value(summary);
}

class _QaSafetyRepository implements SafetyRepository {
  @override
  Future<void> blockUser(String targetUserId) async {}

  @override
  Future<void> reportUser({
    required String targetUserId,
    required SafetyReportReason reason,
    String details = '',
  }) async {}
}
