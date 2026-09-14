import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/main.dart' as sidecar;
import 'package:sidecar/src/routing/app_router.dart';

const _adminEmail = String.fromEnvironment('M6_ADMIN_EMAIL');
const _adminPassword = String.fromEnvironment('M6_ADMIN_PASSWORD');
const _userEmail = String.fromEnvironment('M6_USER_EMAIL');
const _userPassword = String.fromEnvironment('M6_USER_PASSWORD');
const _userUid = String.fromEnvironment('M6_USER_UID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'admin deletion immediately signs the active user out of the running app',
    (tester) async {
      for (final value in [
        _adminEmail,
        _adminPassword,
        _userEmail,
        _userPassword,
        _userUid,
      ]) {
        expect(
          value,
          isNotEmpty,
          reason: 'Live admin QA defines are required.',
        );
      }

      await sidecar.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final primaryAuth = FirebaseAuth.instance;
      await primaryAuth.signOut();

      final adminApp = await Firebase.initializeApp(
        name: 'sidecar-admin-deletion-qa',
        options: Firebase.app().options,
      );
      final adminAuth = FirebaseAuth.instanceFor(app: adminApp);
      final adminFunctions = FirebaseFunctions.instanceFor(
        app: adminApp,
        region: 'us-central1',
      );
      addTearDown(() async {
        await primaryAuth.signOut();
        await adminAuth.signOut();
        await adminApp.delete();
      });

      await adminAuth
          .signInWithEmailAndPassword(
            email: _adminEmail,
            password: _adminPassword,
          )
          .timeout(const Duration(seconds: 40));
      final adminToken = await adminAuth.currentUser!
          .getIdTokenResult(true)
          .timeout(const Duration(seconds: 30));
      expect(adminToken.claims?['admin'], isTrue);
      await adminFunctions
          .httpsCallable('adminVerifyUserEmail')
          .call<void>({'uid': _userUid})
          .timeout(const Duration(seconds: 40));

      await primaryAuth
          .signInWithEmailAndPassword(
            email: _userEmail,
            password: _userPassword,
          )
          .timeout(const Duration(seconds: 40));
      await primaryAuth.currentUser!.getIdToken(true);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      // Exercise deletion away from the home shell so this verifies that the
      // app-level revocation gate works regardless of the active section.
      container.read(appRouterProvider).go(AppRoutes.account);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(primaryAuth.currentUser?.uid, _userUid);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Create account'), findsNothing);

      await adminFunctions
          .httpsCallable('adminDeleteUserAccount')
          .call<void>({
            'uid': _userUid,
            'reason': 'Isolated active-session deletion acceptance test',
            'confirmation': 'DELETE',
          })
          .timeout(const Duration(seconds: 120));

      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.pump(const Duration(seconds: 1));
        if (primaryAuth.currentUser == null &&
            find.text('Find your ride').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(primaryAuth.currentUser, isNull);
      expect(find.text('Find your ride'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);

      await expectLater(
        primaryAuth.signInWithEmailAndPassword(
          email: _userEmail,
          password: _userPassword,
        ),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
