import 'package:sidecar/src/features/profile/domain/user_profile.dart';

enum VerificationStatus {
  notStarted,
  pending,
  verified,
  requiresAction,
  failed;

  static VerificationStatus fromJson(Object? value) {
    return switch (value) {
      'pending' || 'processing' => pending,
      'verified' => verified,
      'requiresAction' || 'requires_input' => requiresAction,
      'failed' || 'canceled' => failed,
      'redacted' => notStarted,
      _ => notStarted,
    };
  }
}

class VehicleProfile {
  const VehicleProfile({
    required this.year,
    required this.make,
    required this.model,
    required this.color,
    required this.licensePlate,
    this.photoUrl = '',
  });

  final int year;
  final String make;
  final String model;
  final String color;
  final String licensePlate;
  final String photoUrl;

  String get makeAndModel => '${make.trim()} ${model.trim()}'.trim();

  bool get isComplete =>
      year >= 1980 &&
      year <= DateTime.now().year + 1 &&
      make.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      color.trim().isNotEmpty &&
      licensePlate.trim().isNotEmpty &&
      photoUrl.trim().isNotEmpty;

  factory VehicleProfile.fromJson(Map<String, dynamic> json) {
    return VehicleProfile(
      year: (json['year'] as num?)?.toInt() ?? 0,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      color: json['color'] as String? ?? '',
      licensePlate: json['licensePlate'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'year': year,
    'make': make.trim(),
    'model': model.trim(),
    'color': color.trim(),
    'licensePlate': licensePlate.trim().toUpperCase(),
    'photoUrl': photoUrl.trim(),
    'complete': isComplete,
  };
}

class VerificationSummary {
  const VerificationSummary({
    this.identity = VerificationStatus.notStarted,
    this.insurance = VerificationStatus.notStarted,
    this.manualInsuranceSubmitted = false,
    this.vehicle,
    this.lastError = '',
  });

  final VerificationStatus identity;
  final VerificationStatus insurance;
  final bool manualInsuranceSubmitted;
  final VehicleProfile? vehicle;
  final String lastError;

  bool get identityComplete => identity == VerificationStatus.verified;
  bool get insuranceComplete => insurance == VerificationStatus.verified;
  bool get vehicleComplete => vehicle?.isComplete == true;

  bool canUseRideFeatures(PrimaryRole role) {
    if (!identityComplete) return false;
    if (role == PrimaryRole.rider) return true;
    return insuranceComplete && vehicleComplete;
  }

  factory VerificationSummary.fromJson(
    Map<String, dynamic>? status,
    Map<String, dynamic>? vehicle,
  ) {
    return VerificationSummary(
      identity: VerificationStatus.fromJson(status?['identityStatus']),
      insurance: VerificationStatus.fromJson(status?['insuranceStatus']),
      manualInsuranceSubmitted:
          status?['manualInsuranceSubmitted'] as bool? ?? false,
      vehicle: vehicle == null ? null : VehicleProfile.fromJson(vehicle),
      lastError: status?['lastError'] as String? ?? '',
    );
  }
}
