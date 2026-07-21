import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/core/config/business_config.dart';

void main() {
  group('BusinessConfig', () {
    final config = BusinessConfig(
      serviceFeeType: ServiceFeeType.percentage,
      serviceFeeValue: 10,
      irsMileageRate: 0,
      pricingMode: PricingMode.driverSetsUnderCap,
      refundRules: const [
        RefundRule(
          minimumHoursBeforeTrip: 24,
          riderRefundPercentage: 100,
          platformPercentage: 0,
          driverPercentage: 0,
        ),
      ],
      paymentExpirationHours: 24,
      tripAutoCompleteHours: 24,
      allowedSchoolDomains: const ['ucsb.edu'],
      allowedTestEmails: const [
        'alijonovshohruhmirzo@gmail.com',
        'shohruh@fera-tech.com',
        'shohruxa26@gmail.com',
        'shohruhmirzoalijonov@gmail.com',
      ],
    );

    test('accepts the configured school domain', () {
      expect(config.allowsEmail('student@ucsb.edu'), isTrue);
      expect(config.allowsEmail('STUDENT@UCSB.EDU'), isTrue);
    });

    test('rejects unconfigured domains including other edu addresses', () {
      expect(config.allowsEmail('student@example.edu'), isFalse);
      expect(config.allowsEmail('another@gmail.com'), isFalse);
      expect(config.allowsEmail('invalid-address'), isFalse);
    });

    test('accepts only configured test email addresses', () {
      expect(config.allowsEmail('alijonovshohruhmirzo@gmail.com'), isTrue);
      expect(config.allowsEmail('SHOHRUH@FERA-TECH.COM'), isTrue);
      expect(config.allowsEmail('shohruxa26@gmail.com'), isTrue);
      expect(config.allowsEmail('shohruhmirzoalijonov@gmail.com'), isTrue);
    });
  });
}
