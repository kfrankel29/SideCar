import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';

void main() {
  const completeVehicle = VehicleProfile(
    year: 2024,
    make: 'Honda',
    model: 'CR-V',
    color: 'White',
    licensePlate: '8ABC123',
    photoUrl: 'https://example.test/vehicle.jpg',
  );

  test('rider requires verified identity before ride features unlock', () {
    expect(
      const VerificationSummary().canUseRideFeatures(PrimaryRole.rider),
      isFalse,
    );
    expect(
      const VerificationSummary(
        identity: VerificationStatus.verified,
      ).canUseRideFeatures(PrimaryRole.rider),
      isTrue,
    );
  });

  test('driver requires identity, vehicle, and insurance', () {
    expect(
      const VerificationSummary(
        identity: VerificationStatus.verified,
        vehicle: completeVehicle,
      ).canUseRideFeatures(PrimaryRole.driver),
      isFalse,
    );
    expect(
      const VerificationSummary(
        identity: VerificationStatus.verified,
        insurance: VerificationStatus.verified,
        vehicle: completeVehicle,
      ).canUseRideFeatures(PrimaryRole.driver),
      isTrue,
    );
  });

  test('vehicle validation rejects incomplete or invalid details', () {
    expect(completeVehicle.isComplete, isTrue);
    expect(
      const VehicleProfile(
        year: 1979,
        make: 'Honda',
        model: 'CR-V',
        color: 'White',
        licensePlate: '8ABC123',
      ).isComplete,
      isFalse,
    );
    expect(
      const VehicleProfile(
        year: 2024,
        make: 'Honda',
        model: 'CR-V',
        color: 'White',
        licensePlate: '8ABC123',
      ).isComplete,
      isFalse,
    );
  });

  test('provider status values map to safe app states', () {
    expect(
      VerificationStatus.fromJson('verified'),
      VerificationStatus.verified,
    );
    expect(
      VerificationStatus.fromJson('requires_input'),
      VerificationStatus.requiresAction,
    );
    expect(
      VerificationStatus.fromJson('redacted'),
      VerificationStatus.notStarted,
    );
    expect(
      VerificationStatus.fromJson('unexpected'),
      VerificationStatus.notStarted,
    );
  });
}
