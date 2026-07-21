enum ServiceFeeType { percentage, fixed }

enum PricingMode { driverSetsUnderCap, platformCalculated }

class RefundRule {
  const RefundRule({
    required this.minimumHoursBeforeTrip,
    required this.riderRefundPercentage,
    required this.platformPercentage,
    required this.driverPercentage,
  });

  final int minimumHoursBeforeTrip;
  final double riderRefundPercentage;
  final double platformPercentage;
  final double driverPercentage;

  factory RefundRule.fromJson(Map<String, Object?> json) {
    return RefundRule(
      minimumHoursBeforeTrip: (json['minimumHoursBeforeTrip'] as num).toInt(),
      riderRefundPercentage: (json['riderRefundPercentage'] as num).toDouble(),
      platformPercentage: (json['platformPercentage'] as num).toDouble(),
      driverPercentage: (json['driverPercentage'] as num).toDouble(),
    );
  }
}

class BusinessConfig {
  BusinessConfig({
    required this.serviceFeeType,
    required this.serviceFeeValue,
    required this.irsMileageRate,
    required this.pricingMode,
    required this.paymentExpirationHours,
    required this.tripAutoCompleteHours,
    required Iterable<RefundRule> refundRules,
    required Iterable<String> allowedSchoolDomains,
    required Iterable<String> allowedTestEmails,
    this.version = 'local-default',
  }) : refundRules = List.unmodifiable(refundRules),
       allowedSchoolDomains = Set.unmodifiable(
         allowedSchoolDomains
             .map(_normalizeDomain)
             .where((value) => value.isNotEmpty),
       ),
       allowedTestEmails = Set.unmodifiable(
         allowedTestEmails
             .map(_normalizeEmail)
             .where((value) => value.isNotEmpty),
       ) {
    if (serviceFeeValue < 0 || irsMileageRate < 0) {
      throw ArgumentError('Fee and mileage values cannot be negative.');
    }
    if (paymentExpirationHours < 1 || tripAutoCompleteHours < 1) {
      throw ArgumentError('Configuration durations must be positive.');
    }
    if (this.allowedSchoolDomains.isEmpty) {
      throw ArgumentError('At least one school email domain is required.');
    }
    for (final rule in this.refundRules) {
      final values = [
        rule.riderRefundPercentage,
        rule.platformPercentage,
        rule.driverPercentage,
      ];
      if (values.any((value) => value < 0 || value > 100)) {
        throw ArgumentError('Refund percentages must be between 0 and 100.');
      }
    }
  }

  final ServiceFeeType serviceFeeType;
  final double serviceFeeValue;
  final double irsMileageRate;
  final PricingMode pricingMode;
  final int paymentExpirationHours;
  final int tripAutoCompleteHours;
  final List<RefundRule> refundRules;
  final Set<String> allowedSchoolDomains;
  final Set<String> allowedTestEmails;
  final String version;

  bool allowsEmail(String email) {
    final normalizedEmail = _normalizeEmail(email);
    final separator = normalizedEmail.lastIndexOf('@');
    if (separator < 1 || separator == normalizedEmail.length - 1) return false;
    if (allowedTestEmails.contains(normalizedEmail)) return true;
    return allowedSchoolDomains.contains(
      _normalizeDomain(normalizedEmail.substring(separator + 1)),
    );
  }

  static String _normalizeEmail(String value) => value.trim().toLowerCase();

  static String _normalizeDomain(String value) {
    return value.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
  }
}
