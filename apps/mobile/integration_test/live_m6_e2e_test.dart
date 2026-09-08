import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('activates every live Milestone 6 business setting', (
    tester,
  ) async {
    final bootstrap = await AppBootstrap.initialize();
    expect(
      bootstrap.firebaseReady,
      isTrue,
      reason:
          'Firebase initialization failed: ${bootstrap.initializationError}',
    );

    final config = await bootstrap.businessConfigRepository.refresh();
    expect(config.version, startsWith('m6-'));
    expect(config.serviceFeeType.name, 'percentage');
    expect(config.serviceFeeValue, 8);
    expect(config.irsMileageRate, 0.76);
    expect(config.paymentExpirationHours, 24);
    expect(config.tripAutoCompleteHours, 48);
    expect(config.refundRules, hasLength(3));
    expect(config.refundRules.first.minimumHoursBeforeTrip, 168);
    expect(config.refundRules.first.riderRefundPercentage, 100);
    expect(config.refundRules[1].minimumHoursBeforeTrip, 24);
    expect(config.refundRules[1].platformPercentage, 8);
    expect(config.refundRules.last.minimumHoursBeforeTrip, 0);
    expect(config.refundRules.last.driverPercentage, 92);
  });
}
