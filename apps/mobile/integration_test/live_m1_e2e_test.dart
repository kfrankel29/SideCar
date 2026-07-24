import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const phase = String.fromEnvironment('M1_E2E_PHASE');
  const email = String.fromEnvironment('M1_E2E_EMAIL');
  const password = String.fromEnvironment('M1_E2E_PASSWORD');
  const code = String.fromEnvironment('M1_E2E_CODE');
  const newPassword = String.fromEnvironment('M1_E2E_NEW_PASSWORD');

  testWidgets('live Milestone 1 phase: $phase', (tester) async {
    expect(email, isNotEmpty, reason: 'M1_E2E_EMAIL is required.');
    final bootstrap = await AppBootstrap.initialize();
    expect(
      bootstrap.firebaseReady,
      isTrue,
      reason:
          'Firebase initialization failed: ${bootstrap.initializationError}',
    );

    final auth = bootstrap.authRepository;
    final profiles = bootstrap.profileRepository;

    switch (phase) {
      case 'readiness':
        final config = await bootstrap.businessConfigRepository.refresh();
        expect(config.allowsEmail(email), isTrue);
        expect(config.version, isNot('local-default'));
        expect(config.serviceFeeValue, 10);
      case 'request-reset':
        await auth.requestPasswordResetCode(email);
      case 'reject-email':
        expect(password, isNotEmpty);
        AppFailure? rejection;
        try {
          await auth.createStudentAccount(
            firstName: 'Test',
            lastName: 'Student',
            email: email,
            password: password,
          );
        } on AppFailure catch (error) {
          rejection = error;
        }
        expect(rejection, isNotNull);
        expect(rejection!.message, contains('ucsb.edu email required'));
      case 'reset-existing':
        expect(code, matches(RegExp(r'^\d{6}$')));
        expect(newPassword, isNotEmpty);
        final resetToken = await auth.verifyPasswordResetCode(
          email: email,
          code: code,
        );
        await auth.completePasswordReset(
          email: email,
          resetToken: resetToken,
          newPassword: newPassword,
        );
        final user = await auth.signIn(email: email, password: newPassword);
        expect(user.email, email);
      case 'create':
        expect(password, isNotEmpty);
        final user = await auth.createStudentAccount(
          firstName: 'Shohruh',
          lastName: 'Alijonov',
          email: email,
          password: password,
        );
        expect(user.email, email);
        expect(user.emailVerified, isFalse);
      case 'verify-profile':
        expect(password, isNotEmpty);
        expect(code, matches(RegExp(r'^\d{6}$')));
        await auth.signIn(email: email, password: password);
        await auth.verifyEmailCode(code);
        expect(auth.currentUser?.emailVerified, isTrue);
        final userId = auth.currentUser!.id;
        final photoUrl = await profiles.uploadProfilePhoto(
          bytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
          ),
          contentType: 'image/png',
        );
        final profile = UserProfile(
          userId: userId,
          firstName: 'Shohruh',
          lastName: 'Alijonov',
          school: 'UC Santa Barbara',
          age: 20,
          gender: 'Male',
          language: 'English',
          photoUrl: photoUrl,
        );
        await profiles.saveProfile(profile);
        await profiles.setPrimaryRole(PrimaryRole.rider);
        final saved = await profiles.loadCurrentProfile();
        expect(saved?.isComplete, isTrue);
        expect(saved?.primaryRole, PrimaryRole.rider);
        await auth.signOut();
        final signedIn = await auth.signIn(email: email, password: password);
        expect(signedIn.emailVerified, isTrue);
      case 'complete-reset':
        expect(code, matches(RegExp(r'^\d{6}$')));
        expect(newPassword, isNotEmpty);
        final resetToken = await auth.verifyPasswordResetCode(
          email: email,
          code: code,
        );
        await auth.completePasswordReset(
          email: email,
          resetToken: resetToken,
          newPassword: newPassword,
        );
        if (password.isNotEmpty) {
          AppFailure? oldPasswordFailure;
          try {
            await auth.signIn(email: email, password: password);
          } on AppFailure catch (error) {
            oldPasswordFailure = error;
          }
          expect(oldPasswordFailure, isNotNull);
        }
        final signedIn = await auth.signIn(email: email, password: newPassword);
        expect(signedIn.emailVerified, isTrue);
      case 'cleanup':
        expect(password, isNotEmpty);
        await auth.signIn(email: email, password: password);
        final firebaseUser = FirebaseAuth.instance.currentUser!;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .delete();
        try {
          await FirebaseStorage.instance
              .ref('users/${firebaseUser.uid}/profile/profile.jpg')
              .delete();
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
        await firebaseUser.delete();
        expect(FirebaseAuth.instance.currentUser, isNull);
      case 'assert-deleted':
        expect(password, isNotEmpty);
        AppFailure? deletedAccountFailure;
        try {
          await auth.signIn(email: email, password: password);
        } on AppFailure catch (error) {
          deletedAccountFailure = error;
        }
        expect(deletedAccountFailure, isNotNull);
      default:
        fail('Unknown M1_E2E_PHASE: $phase');
    }
  });
}
