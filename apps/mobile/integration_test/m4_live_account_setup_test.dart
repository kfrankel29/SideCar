import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const phase = String.fromEnvironment('M4_SETUP_PHASE');
  const email = String.fromEnvironment('M4_SETUP_EMAIL');
  const password = String.fromEnvironment('M4_SETUP_PASSWORD');
  const roleName = String.fromEnvironment('M4_SETUP_ROLE');
  const code = String.fromEnvironment('M4_SETUP_CODE');

  testWidgets('provisions an isolated M4 test account', (tester) async {
    expect(email, isNotEmpty);
    expect(password, isNotEmpty);
    final bootstrap = await AppBootstrap.initialize();
    expect(bootstrap.firebaseReady, isTrue);

    switch (phase) {
      case 'signup':
        await bootstrap.authRepository.signOut();
        final user = await bootstrap.authRepository.createStudentAccount(
          firstName: roleName == 'driver' ? 'M4 Driver' : 'M4 Rider',
          lastName: 'QA',
          email: email,
          password: password,
        );
        expect(user.emailVerified, isFalse);
        debugPrint('M4_SETUP_RESULT=signup:${user.id}');
        return;
      case 'resend':
        await bootstrap.authRepository.signOut();
        await bootstrap.authRepository.signIn(email: email, password: password);
        try {
          await bootstrap.authRepository.resendEmailVerificationCode();
        } on AppFailure catch (error) {
          debugPrint('M4_SETUP_ERROR=${error.code}:${error.message}');
          rethrow;
        }
        debugPrint('M4_SETUP_RESULT=resent');
        return;
      case 'verify':
        expect(code, matches(RegExp(r'^\d{6}$')));
        await bootstrap.authRepository.signOut();
        final user = await bootstrap.authRepository.signIn(
          email: email,
          password: password,
        );
        if (!user.emailVerified) {
          await bootstrap.authRepository.verifyEmailCode(code);
        }
        final signedIn = bootstrap.authRepository.currentUser;
        expect(signedIn, isNotNull);
        final account = signedIn!;
        final role = roleName == 'driver'
            ? PrimaryRole.driver
            : PrimaryRole.rider;
        final currentProfile = await bootstrap.profileRepository
            .loadCurrentProfile();
        if (currentProfile?.isComplete != true ||
            currentProfile?.primaryRole != role) {
          await bootstrap.profileRepository.saveProfile(
            UserProfile(
              userId: account.id,
              firstName: role == PrimaryRole.driver ? 'M4 Driver' : 'M4 Rider',
              lastName: 'QA',
              school: 'UC Santa Barbara',
              age: 24,
              gender: role == PrimaryRole.driver ? 'Male' : 'Female',
              language: 'English',
              photoUrl: role == PrimaryRole.driver
                  ? 'https://i.pravatar.cc/256?img=12'
                  : 'https://i.pravatar.cc/256?img=47',
              primaryRole: role,
            ),
          );
        }
        final verificationUrl = await bootstrap.verificationRepository
            .createIdentityVerificationSession();
        debugPrint('M4_IDENTITY_URL=$verificationUrl');
        debugPrint('M4_SETUP_RESULT=verified:${account.id}');
        return;
      case 'driver-readiness':
        await bootstrap.authRepository.signOut();
        await bootstrap.authRepository.signIn(email: email, password: password);
        await bootstrap.verificationRepository.saveVehicle(
          VehicleProfile(
            year: 2024,
            make: 'Honda',
            model: 'Civic',
            color: 'Black',
            licensePlate: 'M4QA0810',
            photoUrl:
                'https://images.unsplash.com/photo-1542362567-b07e54358753?w=800',
          ),
        );
        await bootstrap.verificationRepository.verifyInsuranceForTesting();
        final verification = await bootstrap.verificationRepository
            .loadCurrentVerification();
        expect(verification.identityComplete, isTrue);
        expect(verification.vehicleComplete, isTrue);
        expect(verification.insuranceComplete, isTrue);
        final onboardingUrl = await bootstrap.bookingRepository
            .createDriverOnboardingLink();
        debugPrint('M4_CONNECT_URL=$onboardingUrl');
        debugPrint('M4_SETUP_RESULT=driver-ready');
        return;
      case 'status':
        await bootstrap.authRepository.signOut();
        await bootstrap.authRepository.signIn(email: email, password: password);
        final profile = await bootstrap.profileRepository.loadCurrentProfile();
        final verification = await bootstrap.verificationRepository
            .loadCurrentVerification();
        final result = <String, Object?>{
          'profileComplete': profile?.isComplete,
          'role': profile?.primaryRole?.name,
          'identity': verification.identity.name,
          'vehicleComplete': verification.vehicleComplete,
          'insurance': verification.insurance.name,
        };
        if (profile?.primaryRole == PrimaryRole.driver &&
            verification.identityComplete &&
            verification.vehicleComplete &&
            verification.insuranceComplete) {
          final payout = await bootstrap.bookingRepository
              .getDriverPayoutStatus();
          result['payoutsEnabled'] = payout.payoutsEnabled;
        }
        debugPrint('M4_SETUP_RESULT=${jsonEncode(result)}');
        return;
      default:
        fail(
          'Set M4_SETUP_PHASE to signup, resend, verify, driver-readiness, or status.',
        );
    }
  });
}
