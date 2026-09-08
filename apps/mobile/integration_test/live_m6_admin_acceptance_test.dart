import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';

const _adminEmail = String.fromEnvironment('M6_ADMIN_EMAIL');
const _adminPassword = String.fromEnvironment('M6_ADMIN_PASSWORD');
const _adminUid = String.fromEnvironment('M6_ADMIN_UID');
const _userEmail = String.fromEnvironment('M6_USER_EMAIL');
const _userPassword = String.fromEnvironment('M6_USER_PASSWORD');
const _userUid = String.fromEnvironment('M6_USER_UID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'completes every live Milestone 6 admin operation',
    (tester) async {
      for (final value in [
        _adminEmail,
        _adminPassword,
        _adminUid,
        _userEmail,
        _userPassword,
        _userUid,
      ]) {
        expect(value, isNotEmpty, reason: 'M6 fixture defines are required.');
      }

      final bootstrap = await AppBootstrap.initialize();
      expect(
        bootstrap.firebaseReady,
        isTrue,
        reason:
            'Firebase initialization failed: ${bootstrap.initializationError}',
      );
      final auth = FirebaseAuth.instance;
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final remoteConfig = FirebaseRemoteConfig.instance;
      Map<String, dynamic>? originalConfig;
      var configNeedsRestore = false;

      Future<void> signInAdmin() async {
        await auth.signOut().timeout(const Duration(seconds: 20));
        final credential = await auth
            .signInWithEmailAndPassword(
              email: _adminEmail,
              password: _adminPassword,
            )
            .timeout(const Duration(seconds: 40));
        expect(credential.user?.uid, _adminUid);
        final token = await credential.user!
            .getIdTokenResult(true)
            .timeout(const Duration(seconds: 30));
        expect(token.claims?['admin'], isTrue);
      }

      Future<Map<String, dynamic>> call(
        String name, [
        Map<String, dynamic> payload = const {},
      ]) async {
        final result = await functions
            .httpsCallable(name)
            .call<Map<String, dynamic>>(payload)
            .timeout(const Duration(seconds: 40));
        return Map<String, dynamic>.from(result.data);
      }

      Future<void> setUserStatus(String status, {String reason = ''}) async {
        await call('adminSetUserStatus', {
          'uid': _userUid,
          'status': status,
          'reason': reason,
        });
      }

      Future<void> expectDisabledSignIn(String expectedState) async {
        await auth.signOut();
        try {
          await bootstrap.authRepository
              .signIn(email: _userEmail, password: _userPassword)
              .timeout(const Duration(seconds: 40));
          fail('$expectedState user unexpectedly signed in.');
        } on AppFailure catch (error) {
          expect(error.code, 'user-disabled');
          expect(
            error.message,
            'This account has been disabled. Contact SideCar support for help.',
          );
        }
      }

      Future<void> publishConfig(Map<String, dynamic> config) async {
        await call('adminUpdateConfig', {'config': config});
      }

      Future<void> waitForRemoteConfig({
        required num serviceFeeValue,
        required num stripeCardPercentage,
        required num irsMileageRate,
        required int paymentExpirationHours,
        required int tripAutoCompleteHours,
      }) async {
        await remoteConfig.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 15),
            minimumFetchInterval: Duration.zero,
          ),
        );
        for (var attempt = 0; attempt < 10; attempt++) {
          await remoteConfig.fetchAndActivate().timeout(
            const Duration(seconds: 20),
          );
          final matches =
              remoteConfig.getDouble('service_fee_value') == serviceFeeValue &&
              remoteConfig.getDouble('stripe_card_percentage') ==
                  stripeCardPercentage &&
              remoteConfig.getDouble('irs_mileage_rate') == irsMileageRate &&
              remoteConfig.getInt('payment_expiration_hours') ==
                  paymentExpirationHours &&
              remoteConfig.getInt('trip_auto_complete_hours') ==
                  tripAutoCompleteHours;
          if (matches) return;
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        fail('The simulator did not activate the published business config.');
      }

      addTearDown(() async {
        try {
          debugPrint('M6_ADMIN_STEP=restore');
          await signInAdmin();
          await setUserStatus('active');
          if (configNeedsRestore && originalConfig != null) {
            await publishConfig(originalConfig);
          }
        } finally {
          await auth.signOut().timeout(const Duration(seconds: 20));
        }
      });

      debugPrint('M6_ADMIN_STEP=sign-in');
      await signInAdmin();

      debugPrint('M6_ADMIN_STEP=overview');
      final overview = await call('adminGetOverview');
      final counts = Map<String, dynamic>.from(overview['counts'] as Map);
      expect(counts['users'], greaterThanOrEqualTo(4));
      expect(counts['rides'], isA<int>());
      expect(counts['bookings'], isA<int>());
      expect(counts['disputes'], isA<int>());

      debugPrint('M6_ADMIN_STEP=users');
      final users = await call('adminListUsers');
      final listedUsers = List<Map<String, dynamic>>.from(
        (users['users'] as List).map(
          (value) => Map<String, dynamic>.from(value),
        ),
      );
      expect(
        listedUsers.any(
          (user) => user['uid'] == _adminUid && user['isAdmin'] == true,
        ),
        isTrue,
      );
      expect(listedUsers.any((user) => user['uid'] == _userUid), isTrue);
      expect(
        listedUsers.singleWhere(
          (user) => user['uid'] == _userUid,
        )['emailVerified'],
        isFalse,
      );

      debugPrint('M6_ADMIN_STEP=verify-email');
      await call('adminVerifyUserEmail', {'uid': _userUid});
      final usersAfterVerification = await call('adminListUsers');
      final verifiedUser = List<Map<String, dynamic>>.from(
        (usersAfterVerification['users'] as List).map(
          (value) => Map<String, dynamic>.from(value),
        ),
      ).singleWhere((user) => user['uid'] == _userUid);
      expect(verifiedUser['emailVerified'], isTrue);

      debugPrint('M6_ADMIN_STEP=self-lockout');
      try {
        await call('adminSetUserStatus', {
          'uid': _adminUid,
          'status': 'suspended',
          'reason': 'M6 self-lockout protection test',
        });
        fail('An administrator was able to suspend their own account.');
      } on FirebaseFunctionsException catch (error) {
        expect(error.code, 'failed-precondition');
      }

      debugPrint('M6_ADMIN_STEP=config');
      final configResponse = await call('adminGetConfig');
      final liveConfig = Map<String, dynamic>.from(
        configResponse['config'] as Map,
      );
      originalConfig = {
        'serviceFeeType': liveConfig['serviceFeeType'],
        'serviceFeeValue': liveConfig['serviceFeeValue'],
        'stripeCardPercentage': liveConfig['stripeCardPercentage'],
        'irsMileageRate': liveConfig['irsMileageRate'],
        'refundRules': liveConfig['refundRules'],
        'paymentExpirationHours': liveConfig['paymentExpirationHours'],
        'tripAutoCompleteHours': liveConfig['tripAutoCompleteHours'],
      };
      final temporaryConfig = Map<String, dynamic>.from(originalConfig);
      final originalFee = (originalConfig['serviceFeeValue'] as num).toDouble();
      final originalMileage = (originalConfig['irsMileageRate'] as num)
          .toDouble();
      temporaryConfig['serviceFeeValue'] = originalFee + 0.25;
      temporaryConfig['stripeCardPercentage'] = 0.0;
      temporaryConfig['irsMileageRate'] = originalMileage + 0.001;
      temporaryConfig['paymentExpirationHours'] =
          (originalConfig['paymentExpirationHours'] as int) + 1;
      temporaryConfig['tripAutoCompleteHours'] =
          (originalConfig['tripAutoCompleteHours'] as int) + 1;
      await publishConfig(temporaryConfig);
      configNeedsRestore = true;
      await waitForRemoteConfig(
        serviceFeeValue: temporaryConfig['serviceFeeValue'] as num,
        stripeCardPercentage: temporaryConfig['stripeCardPercentage'] as num,
        irsMileageRate: temporaryConfig['irsMileageRate'] as num,
        paymentExpirationHours:
            temporaryConfig['paymentExpirationHours'] as int,
        tripAutoCompleteHours: temporaryConfig['tripAutoCompleteHours'] as int,
      );
      await publishConfig(originalConfig);
      configNeedsRestore = false;
      await waitForRemoteConfig(
        serviceFeeValue: originalConfig['serviceFeeValue'] as num,
        stripeCardPercentage: originalConfig['stripeCardPercentage'] as num,
        irsMileageRate: originalConfig['irsMileageRate'] as num,
        paymentExpirationHours: originalConfig['paymentExpirationHours'] as int,
        tripAutoCompleteHours: originalConfig['tripAutoCompleteHours'] as int,
      );

      debugPrint('M6_ADMIN_STEP=moderation');
      await setUserStatus('suspended', reason: 'M6 suspension acceptance test');
      await expectDisabledSignIn('Suspended');
      await signInAdmin();
      await setUserStatus('active');
      await auth.signOut();
      final restored = await bootstrap.authRepository
          .signIn(email: _userEmail, password: _userPassword)
          .timeout(const Duration(seconds: 40));
      expect(restored.id, _userUid);

      await signInAdmin();
      await setUserStatus('banned', reason: 'M6 ban acceptance test');
      await expectDisabledSignIn('Banned');
      await signInAdmin();
      await setUserStatus('active');

      debugPrint('M6_ADMIN_STEP=records');
      for (final kind in [
        'rides',
        'bookings',
        'payments',
        'refunds',
        'disputes',
      ]) {
        final result = await call('adminListRecords', {'kind': kind});
        expect(result['records'], isA<List>());
        expect(result['nextCursor'], isA<String>());
      }
      final audit = await call('adminListRecords', {'kind': 'audit'});
      final actions = (audit['records'] as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .where((value) => value['adminUid'] == _adminUid)
          .map((value) => value['action'])
          .toSet();
      expect(
        actions,
        containsAll(<String>{
          'config.updated',
          'insurance.verified',
          'insurance.rejected',
          'user.suspended',
          'user.banned',
          'user.active',
          'user.email_verified',
        }),
      );
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
