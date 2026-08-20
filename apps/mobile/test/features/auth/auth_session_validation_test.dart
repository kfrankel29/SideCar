import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/app.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';

void main() {
  const restoredUser = AccountUser(
    id: 'restored-user',
    email: 'student@ucsb.edu',
    emailVerified: true,
  );
  const incompleteProfile = UserProfile(
    userId: 'restored-user',
    firstName: 'Test',
    lastName: 'Student',
    school: 'UC Santa Barbara',
    photoUrl: '',
  );
  const completeProfile = UserProfile(
    userId: 'restored-user',
    firstName: 'Test',
    lastName: 'Student',
    school: 'UC Santa Barbara',
    age: 20,
    gender: 'Female',
    language: 'English',
    photoUrl: 'https://example.com/profile.jpg',
  );

  testWidgets('a server-deleted restored session returns to onboarding', (
    tester,
  ) async {
    final auth = _SessionAuthRepository(
      currentUser: restoredUser,
      validatedUser: null,
    );

    await tester.pumpWidget(_testApp(auth, _MemoryProfileRepository(null)));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(auth.validationCount, 1);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('For students. By students.'), findsOneWidget);
  });

  testWidgets('a missing server profile signs out a restored auth session', (
    tester,
  ) async {
    final auth = _SessionAuthRepository(
      currentUser: restoredUser,
      validatedUser: restoredUser,
    );

    await tester.pumpWidget(_testApp(auth, _MemoryProfileRepository(null)));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(auth.signOutCount, 1);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('an incomplete server profile continues profile setup', (
    tester,
  ) async {
    final auth = _SessionAuthRepository(
      currentUser: restoredUser,
      validatedUser: restoredUser,
    );

    await tester.pumpWidget(
      _testApp(auth, _MemoryProfileRepository(incompleteProfile)),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Set up your profile'), findsOneWidget);
  });

  testWidgets('a complete profile without a role opens role selection', (
    tester,
  ) async {
    final auth = _SessionAuthRepository(
      currentUser: restoredUser,
      validatedUser: restoredUser,
    );

    await tester.pumpWidget(
      _testApp(auth, _MemoryProfileRepository(completeProfile)),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Welcome aboard, Test'), findsOneWidget);
  });

  testWidgets('a saved role does not repeat role onboarding at launch', (
    tester,
  ) async {
    final auth = _SessionAuthRepository(
      currentUser: restoredUser,
      validatedUser: restoredUser,
    );
    final profile = completeProfile.copyWith(primaryRole: PrimaryRole.rider);

    await tester.pumpWidget(_testApp(auth, _MemoryProfileRepository(profile)));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Hey, Test'), findsOneWidget);
    expect(find.text('Welcome aboard, Test'), findsNothing);
    expect(find.text('Your profile is ready'), findsNothing);
  });

  testWidgets('a completed profile can log out for account testing', (
    tester,
  ) async {
    final auth = _SessionAuthRepository(
      currentUser: restoredUser,
      validatedUser: restoredUser,
    );
    final profile = completeProfile.copyWith(primaryRole: PrimaryRole.rider);

    await tester.pumpWidget(_testApp(auth, _MemoryProfileRepository(profile)));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ride-nav-4')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Log out'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(auth.signOutCount, 1);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('choosing a role persists it and leaves role onboarding', (
    tester,
  ) async {
    final auth = _SessionAuthRepository(
      currentUser: restoredUser,
      validatedUser: restoredUser,
    );
    final profiles = _MemoryProfileRepository(completeProfile);

    await tester.pumpWidget(_testApp(auth, profiles));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book a ride'));
    await tester.pumpAndSettle();

    expect(profiles.profile?.primaryRole, PrimaryRole.rider);
    expect(find.text('Hey, Test'), findsOneWidget);
    expect(find.text('Your profile is ready'), findsNothing);
  });

  testWidgets('a deleted server profile is rechecked when the app resumes', (
    tester,
  ) async {
    final auth = _SessionAuthRepository(
      currentUser: restoredUser,
      validatedUser: restoredUser,
    );
    final profiles = _MemoryProfileRepository(incompleteProfile);

    await tester.pumpWidget(_testApp(auth, profiles));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('Set up your profile'), findsOneWidget);

    profiles.profile = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(auth.validationCount, 2);
    expect(auth.signOutCount, 1);
    expect(find.text('Create account'), findsOneWidget);
  });
}

Widget _testApp(AuthRepository auth, ProfileRepository profiles) {
  return ProviderScope(
    overrides: [
      businessConfigRepositoryProvider.overrideWithValue(
        MemoryBusinessConfigRepository(localDisplayConfig()),
      ),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles),
      rideRepositoryProvider.overrideWithValue(const _EmptyRideRepository()),
      verificationRepositoryProvider.overrideWithValue(
        const _MemoryVerificationRepository(),
      ),
    ],
    child: const SideCarApp(),
  );
}

class _EmptyRideRepository implements RideRepository {
  @override
  void invalidateRide(String rideId) {}

  const _EmptyRideRepository();

  @override
  Future<void> cancelRide(String rideId) async {}

  @override
  Future<Ride> createRide(RideDraft draft) => throw UnimplementedError();

  @override
  Future<Ride> getRide(String rideId) => throw UnimplementedError();

  @override
  Future<RideStopPickerContext> getRideStopPickerContext(
    String rideId, {
    String selectedPlaceId = '',
  }) => throw UnimplementedError();

  @override
  Future<RidePlacePrediction> resolveRideStopPin(
    String rideId, {
    required double latitude,
    required double longitude,
  }) => throw UnimplementedError();

  @override
  Future<LiveTripPlan> getLiveTrip(String rideId) => throw UnimplementedError();

  @override
  Future<LiveTripPlan> startLiveTrip(String rideId) =>
      throw UnimplementedError();

  @override
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async =>
      const [];

  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async => const [];

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      const [];

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async => const [];

  @override
  Future<Ride> updateRide(RideUpdate update) => throw UnimplementedError();
}

class _MemoryVerificationRepository implements VerificationRepository {
  const _MemoryVerificationRepository();

  static const _summary = VerificationSummary(
    identity: VerificationStatus.verified,
    insurance: VerificationStatus.verified,
    vehicle: VehicleProfile(
      year: 2022,
      make: 'Honda',
      model: 'Civic',
      color: 'Black',
      licensePlate: 'TEST123',
      photoUrl: 'https://example.com/car.jpg',
    ),
  );

  @override
  Future<VerificationSummary> loadCurrentVerification() async => _summary;

  @override
  Stream<VerificationSummary> watchCurrentVerification() =>
      Stream.value(_summary);

  @override
  Future<Uri> createIdentityVerificationSession() => throw UnimplementedError();

  @override
  Future<void> saveVehicle(VehicleProfile vehicle) =>
      throw UnimplementedError();

  @override
  Future<void> submitInsuranceDocument({
    required Uint8List bytes,
    required String contentType,
  }) => throw UnimplementedError();

  @override
  Future<String> uploadVehiclePhoto({
    required Uint8List bytes,
    required String contentType,
  }) => throw UnimplementedError();

  @override
  Future<void> verifyInsuranceForTesting() => throw UnimplementedError();
}

class _SessionAuthRepository implements AuthRepository {
  _SessionAuthRepository({
    required this.currentUser,
    required this.validatedUser,
  });

  @override
  final AccountUser? currentUser;
  AccountUser? validatedUser;
  int validationCount = 0;
  int signOutCount = 0;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(currentUser);

  @override
  Future<AccountUser?> validateCurrentSession() async {
    validationCount += 1;
    return validatedUser;
  }

  @override
  Future<void> completePasswordReset({
    required String email,
    required String resetToken,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<AccountUser> createStudentAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> requestPasswordResetCode(String email) =>
      throw UnimplementedError();

  @override
  Future<void> resendEmailVerificationCode() => throw UnimplementedError();

  @override
  Future<AccountUser> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AccountUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCount += 1;
  }

  @override
  Future<void> verifyEmailCode(String code) => throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();
}

class _MemoryProfileRepository implements ProfileRepository {
  _MemoryProfileRepository(this.profile);

  UserProfile? profile;

  @override
  Future<UserProfile?> loadCurrentProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> setPrimaryRole(PrimaryRole role) async {
    profile = profile?.copyWith(primaryRole: role);
  }

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://example.com/profile.jpg';

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);
}
