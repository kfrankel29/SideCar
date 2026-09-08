import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';

const _adminEmail = String.fromEnvironment('M6_ADMIN_EMAIL');
const _adminPassword = String.fromEnvironment('M6_ADMIN_PASSWORD');
const _userUid = String.fromEnvironment('M6_USER_UID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'admin manually verifies an exception email account',
    (tester) async {
      expect(_adminEmail, isNotEmpty);
      expect(_adminPassword, isNotEmpty);
      expect(_userUid, isNotEmpty);

      final bootstrap = await AppBootstrap.initialize();
      expect(
        bootstrap.firebaseReady,
        isTrue,
        reason: bootstrap.initializationError?.toString(),
      );
      final auth = FirebaseAuth.instance;
      addTearDown(auth.signOut);
      await auth.signInWithEmailAndPassword(
        email: _adminEmail,
        password: _adminPassword,
      );
      final token = await auth.currentUser!.getIdTokenResult(true);
      expect(token.claims?['admin'], isTrue);

      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      Future<Map<String, dynamic>> call(
        String name, [
        Map<String, dynamic> payload = const {},
      ]) async {
        final result = await functions
            .httpsCallable(name)
            .call<Map<String, dynamic>>(payload);
        return Map<String, dynamic>.from(result.data);
      }

      final before = await call('adminListUsers');
      final beforeUser = List<Map<String, dynamic>>.from(
        (before['users'] as List).map(
          (value) => Map<String, dynamic>.from(value as Map),
        ),
      ).singleWhere((user) => user['uid'] == _userUid);
      expect(beforeUser['emailVerified'], isFalse);

      final response = await call('adminVerifyUserEmail', {'uid': _userUid});
      expect(response['uid'], _userUid);
      expect(response['emailVerified'], isTrue);

      final after = await call('adminListUsers');
      final afterUser = List<Map<String, dynamic>>.from(
        (after['users'] as List).map(
          (value) => Map<String, dynamic>.from(value as Map),
        ),
      ).singleWhere((user) => user['uid'] == _userUid);
      expect(afterUser['emailVerified'], isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
