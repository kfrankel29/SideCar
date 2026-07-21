import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/config/business_config.dart';

abstract interface class BusinessConfigRepository {
  Stream<BusinessConfig> watch();
  Future<BusinessConfig> refresh();
}

final businessConfigRepositoryProvider = Provider<BusinessConfigRepository>(
  (ref) =>
      throw StateError('BusinessConfigRepository has not been initialized.'),
);

final businessConfigProvider = StreamProvider<BusinessConfig>((ref) {
  return ref.watch(businessConfigRepositoryProvider).watch();
});

final class RemoteConfigKeys {
  const RemoteConfigKeys._();

  static const configVersion = 'config_version';
  static const serviceFeeType = 'service_fee_type';
  static const serviceFeeValue = 'service_fee_value';
  static const irsMileageRate = 'irs_mileage_rate';
  static const pricingMode = 'pricing_mode';
  static const refundRules = 'refund_rules_json';
  static const paymentExpirationHours = 'payment_expiration_hours';
  static const tripAutoCompleteHours = 'trip_auto_complete_hours';
  static const allowedSchoolDomains = 'allowed_school_domains';
  static const allowedTestEmails = 'allowed_test_emails';
}

class FirebaseBusinessConfigRepository implements BusinessConfigRepository {
  FirebaseBusinessConfigRepository(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  static const _displayFallbacks = <String, Object>{
    RemoteConfigKeys.configVersion: 'local-default',
    RemoteConfigKeys.serviceFeeType: 'percentage',
    RemoteConfigKeys.serviceFeeValue: 10.0,
    RemoteConfigKeys.irsMileageRate: 0.76,
    RemoteConfigKeys.pricingMode: 'driver_sets_under_cap',
    RemoteConfigKeys.refundRules:
        '[{"minimumHoursBeforeTrip":168,"riderRefundPercentage":100,"platformPercentage":0,"driverPercentage":0},{"minimumHoursBeforeTrip":1,"riderRefundPercentage":50,"platformPercentage":10,"driverPercentage":40},{"minimumHoursBeforeTrip":0,"riderRefundPercentage":0,"platformPercentage":10,"driverPercentage":90}]',
    RemoteConfigKeys.paymentExpirationHours: 24,
    RemoteConfigKeys.tripAutoCompleteHours: 48,
    RemoteConfigKeys.allowedSchoolDomains: '["ucsb.edu"]',
    RemoteConfigKeys.allowedTestEmails: '[]',
  };

  @override
  Stream<BusinessConfig> watch() async* {
    await _configure();
    yield _fromRemoteConfig(_remoteConfig);

    await for (final _ in _remoteConfig.onConfigUpdated) {
      await _remoteConfig.activate();
      yield _fromRemoteConfig(_remoteConfig);
    }
  }

  @override
  Future<BusinessConfig> refresh() async {
    await _configure();
    try {
      await _remoteConfig.fetchAndActivate();
    } on FirebaseException {
      // The last activated values remain available during transient outages.
    }
    return _fromRemoteConfig(_remoteConfig);
  }

  Future<void> _configure() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(minutes: 5),
      ),
    );
    await _remoteConfig.setDefaults(_displayFallbacks);
    try {
      await _remoteConfig.fetchAndActivate();
    } on FirebaseException {
      // Cached or display-only fallback values keep the app readable offline.
    }
  }

  BusinessConfig _fromRemoteConfig(FirebaseRemoteConfig config) {
    return BusinessConfig(
      serviceFeeType:
          config.getString(RemoteConfigKeys.serviceFeeType) == 'fixed'
          ? ServiceFeeType.fixed
          : ServiceFeeType.percentage,
      serviceFeeValue: config.getDouble(RemoteConfigKeys.serviceFeeValue),
      irsMileageRate: config.getDouble(RemoteConfigKeys.irsMileageRate),
      pricingMode:
          config.getString(RemoteConfigKeys.pricingMode) ==
              'platform_calculated'
          ? PricingMode.platformCalculated
          : PricingMode.driverSetsUnderCap,
      refundRules: _decodeRefundRules(
        config.getString(RemoteConfigKeys.refundRules),
      ),
      paymentExpirationHours: config.getInt(
        RemoteConfigKeys.paymentExpirationHours,
      ),
      tripAutoCompleteHours: config.getInt(
        RemoteConfigKeys.tripAutoCompleteHours,
      ),
      allowedSchoolDomains: _decodeDomains(
        config.getString(RemoteConfigKeys.allowedSchoolDomains),
      ),
      allowedTestEmails: _decodeEmails(
        config.getString(RemoteConfigKeys.allowedTestEmails),
      ),
      version: config.getString(RemoteConfigKeys.configVersion),
    );
  }

  Iterable<String> _decodeDomains(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded case final List<dynamic> values) {
        final domains = values.whereType<String>();
        if (domains.isNotEmpty) return domains;
      }
    } on FormatException {
      // Invalid remote data fails closed to the launch school.
    }
    return const ['ucsb.edu'];
  }

  Iterable<String> _decodeEmails(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded case final List<dynamic> values) {
        return values.whereType<String>();
      }
    } on FormatException {
      // Invalid test configuration fails closed.
    }
    return const [];
  }

  Iterable<RefundRule> _decodeRefundRules(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded case final List<dynamic> values) {
        return values.whereType<Map<String, dynamic>>().map(
          (value) => RefundRule.fromJson(value),
        );
      }
    } on Object {
      // The server remains authoritative for money movement.
    }
    return const [
      RefundRule(
        minimumHoursBeforeTrip: 168,
        riderRefundPercentage: 100,
        platformPercentage: 0,
        driverPercentage: 0,
      ),
    ];
  }
}

class MemoryBusinessConfigRepository implements BusinessConfigRepository {
  const MemoryBusinessConfigRepository(this.config);

  final BusinessConfig config;

  @override
  Future<BusinessConfig> refresh() async => config;

  @override
  Stream<BusinessConfig> watch() => Stream.value(config);
}

BusinessConfig localDisplayConfig() {
  return BusinessConfig(
    serviceFeeType: ServiceFeeType.percentage,
    serviceFeeValue: 10,
    irsMileageRate: 0.76,
    pricingMode: PricingMode.driverSetsUnderCap,
    paymentExpirationHours: 24,
    tripAutoCompleteHours: 48,
    refundRules: const [
      RefundRule(
        minimumHoursBeforeTrip: 168,
        riderRefundPercentage: 100,
        platformPercentage: 0,
        driverPercentage: 0,
      ),
    ],
    allowedSchoolDomains: const ['ucsb.edu'],
    allowedTestEmails: const [],
  );
}
