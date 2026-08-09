import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/session/domain/app_flow_state.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';

void main() {
  const completeProfile = UserProfile(
    userId: 'user-1',
    firstName: 'Maya',
    lastName: 'Chen',
    school: 'UC Santa Barbara',
    age: 21,
    gender: 'Female',
    language: 'English',
    photoUrl: 'profile.jpg',
  );
  const verifiedIdentity = VerificationSummary(
    identity: VerificationStatus.verified,
  );
  const verifiedDriver = VerificationSummary(
    identity: VerificationStatus.verified,
    insurance: VerificationStatus.verified,
    vehicle: VehicleProfile(
      year: 2024,
      make: 'Honda',
      model: 'Civic',
      color: 'Black',
      licensePlate: 'SIDECAR',
      photoUrl: 'vehicle.jpg',
    ),
  );

  test('incomplete accounts resume profile setup', () {
    final incomplete = completeProfile.copyWith(photoUrl: '');

    expect(
      resolveAppFlowStage(incomplete, verifiedIdentity),
      AppFlowStage.profileSetup,
    );
  });

  test('complete accounts without a role resume role selection', () {
    expect(
      resolveAppFlowStage(completeProfile, verifiedIdentity),
      AppFlowStage.roleSelection,
    );
  });

  test('riders require identity verification before entering the app', () {
    final rider = completeProfile.copyWith(primaryRole: PrimaryRole.rider);

    expect(
      resolveAppFlowStage(rider, const VerificationSummary()),
      AppFlowStage.verification,
    );
    expect(resolveAppFlowStage(rider, verifiedIdentity), AppFlowStage.main);
  });

  test('drivers require identity, vehicle, and insurance verification', () {
    final driver = completeProfile.copyWith(primaryRole: PrimaryRole.driver);

    expect(
      resolveAppFlowStage(driver, verifiedIdentity),
      AppFlowStage.verification,
    );
    expect(resolveAppFlowStage(driver, verifiedDriver), AppFlowStage.main);
  });
}
