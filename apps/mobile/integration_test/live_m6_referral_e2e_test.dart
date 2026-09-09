import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const firstEmail = String.fromEnvironment('M5_E2E_FIRST_EMAIL');
  const firstPassword = String.fromEnvironment('M5_E2E_FIRST_PASSWORD');
  const secondEmail = String.fromEnvironment('M5_E2E_SECOND_EMAIL');
  const secondPassword = String.fromEnvironment('M5_E2E_SECOND_PASSWORD');

  testWidgets('validates live five-digit referral credit behavior', (
    tester,
  ) async {
    expect(firstEmail, isNotEmpty);
    expect(firstPassword, isNotEmpty);
    expect(secondEmail, isNotEmpty);
    expect(secondPassword, isNotEmpty);

    final bootstrap = await AppBootstrap.initialize();
    expect(bootstrap.firebaseReady, isTrue);
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    Future<Map<String, dynamic>> referralSummary() async {
      final result = await functions.httpsCallable('getReferralCode').call();
      return Map<String, dynamic>.from(result.data as Map);
    }

    await bootstrap.authRepository.signOut();
    final first = await bootstrap.authRepository.signIn(
      email: firstEmail,
      password: firstPassword,
    );
    expect(first.id, isNotEmpty);
    final firstBefore = await referralSummary();
    final firstCode = firstBefore['code'] as String;
    expect(firstCode, matches(RegExp(r'^\d{5}$')));
    await expectLater(
      functions.httpsCallable('redeemReferralCode').call({'code': firstCode}),
      throwsA(
        isA<FirebaseFunctionsException>().having(
          (error) => error.code,
          'code',
          'failed-precondition',
        ),
      ),
    );

    await bootstrap.authRepository.signOut();
    final second = await bootstrap.authRepository.signIn(
      email: secondEmail,
      password: secondPassword,
    );
    expect(second.id, isNot(first.id));
    final secondBefore = await referralSummary();
    final secondCode = secondBefore['code'] as String;
    expect(secondCode, matches(RegExp(r'^\d{5}$')));
    expect(secondCode, isNot(firstCode));

    final secondCreditBefore = (secondBefore['creditCents'] as num).toInt();
    var redeemedNow = false;
    try {
      final result = await functions.httpsCallable('redeemReferralCode').call({
        'code': firstCode,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      expect(data['redeemed'], isTrue);
      expect(data['creditCents'], 500);
      redeemedNow = true;
    } on FirebaseFunctionsException catch (error) {
      expect(
        error.code,
        'already-exists',
        reason: 'Only an earlier successful referral redemption is acceptable.',
      );
    }

    final secondAfter = await referralSummary();
    if (redeemedNow) {
      expect(secondAfter['creditCents'], secondCreditBefore + 500);
      await bootstrap.authRepository.signOut();
      await bootstrap.authRepository.signIn(
        email: firstEmail,
        password: firstPassword,
      );
      final firstAfter = await referralSummary();
      expect(
        (firstAfter['creditCents'] as num).toInt(),
        (firstBefore['creditCents'] as num).toInt(),
        reason: 'Only the account entering the code receives credit.',
      );
    } else {
      expect(
        (secondAfter['creditCents'] as num).toInt(),
        greaterThanOrEqualTo(500),
      );
    }

    await bootstrap.authRepository.signOut();
  });
}
