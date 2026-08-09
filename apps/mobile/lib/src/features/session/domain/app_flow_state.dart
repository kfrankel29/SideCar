import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';

enum AppFlowStage { profileSetup, roleSelection, verification, main }

AppFlowStage resolveAppFlowStage(
  UserProfile profile,
  VerificationSummary verification,
) {
  if (!profile.isComplete) return AppFlowStage.profileSetup;
  final role = profile.primaryRole;
  if (role == null) return AppFlowStage.roleSelection;
  if (!verification.canUseRideFeatures(role)) {
    return AppFlowStage.verification;
  }
  return AppFlowStage.main;
}
