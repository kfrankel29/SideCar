import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/main.dart' as sidecar;
import 'package:sidecar/src/routing/app_router.dart';

const _email = String.fromEnvironment('M5_E2E_SECOND_EMAIL');
const _password = String.fromEnvironment('M5_E2E_SECOND_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'self deletion returns to guest Home without a stale link page',
    (tester) async {
      expect(_email, isNotEmpty);
      expect(_password, isNotEmpty);

      await sidecar.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final auth = FirebaseAuth.instance;
      await auth.signOut();
      await auth
          .signInWithEmailAndPassword(email: _email, password: _password)
          .timeout(const Duration(seconds: 45));
      await auth.currentUser!.getIdToken(true);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(appRouterProvider).go(AppRoutes.deleteAccount);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Delete your account?'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('delete-confirmation-field')),
        'DELETE',
      );
      await tester.enterText(
        find.byKey(const Key('delete-password-field')),
        _password,
      );
      await tester.pump();
      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete account'),
      );
      expect(deleteButton.onPressed, isNotNull);
      deleteButton.onPressed!.call();

      for (var attempt = 0; attempt < 150; attempt++) {
        await tester.pump(const Duration(seconds: 1));
        if (auth.currentUser == null &&
            find.text('Find your ride').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(auth.currentUser, isNull);
      expect(find.text('Find your ride'), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
      expect(find.text('This link is no longer available.'), findsNothing);
      await expectLater(
        auth.signInWithEmailAndPassword(email: _email, password: _password),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
