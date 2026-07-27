import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/features/safety/presentation/safety_screens.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';
import 'package:sidecar/src/features/verification/presentation/verification_screens.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final screens = <String, Widget>{
    'verification hub': const VerificationHubScreen(),
    'identity verification': const IdentityVerificationScreen(),
    'driver license': const DriverLicenseUploadScreen(),
    'vehicle profile': const VehicleProfileScreen(),
    'insurance verification': const InsuranceVerificationScreen(),
    'manual insurance': const InsuranceFallbackScreen(),
    'verification complete': const VerificationCompleteScreen(),
    'safety tools': const SafetyToolsScreen(),
    'block user': const BlockUserScreen(
      targetUserId: 'test-target',
      name: 'Jordan',
    ),
    'report user': const ReportUserScreen(
      targetUserId: 'test-target',
      name: 'Jordan',
    ),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} fits the 375 x 812 design viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              const _ProfileRepository(),
            ),
            verificationRepositoryProvider.overrideWithValue(
              const _VerificationRepository(),
            ),
            safetyRepositoryProvider.overrideWithValue(
              const _SafetyRepository(),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: entry.value),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  }

  testWidgets('manual insurance is unavailable before Axle needs fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verificationRepositoryProvider.overrideWithValue(
            const _VerificationRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const InsuranceVerificationScreen(),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Automatic check unavailable'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('manual insurance is offered after Axle failure', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verificationRepositoryProvider.overrideWithValue(
            const _VerificationRepository(
              summary: VerificationSummary(
                insurance: VerificationStatus.failed,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const InsuranceVerificationScreen(),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Upload insurance document'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('driver license uses the approved Final Draft upload copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verificationRepositoryProvider.overrideWithValue(
            const _VerificationRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DriverLicenseUploadScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Required · not uploaded'), findsNWidgets(2));
    expect(find.text('Required · collected by Stripe'), findsNothing);
  });

  testWidgets('vehicle form matches the Final Draft field structure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verificationRepositoryProvider.overrideWithValue(
            const _VerificationRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VehicleProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make and model'), findsOneWidget);
    expect(find.text('Make'), findsNothing);
    expect(find.text('Model'), findsNothing);
    expect(find.text('Vehicle photo'), findsOneWidget);
  });

  testWidgets('vehicle cannot be completed without an exterior photo', (
    tester,
  ) async {
    const summary = VerificationSummary(
      vehicle: VehicleProfile(
        year: 2024,
        make: 'Honda',
        model: 'CR-V',
        color: 'White',
        licensePlate: '8ABC123',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          verificationRepositoryProvider.overrideWithValue(
            const _VerificationRepository(summary: summary),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VehicleProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save vehicle'));
    await tester.pump();

    expect(find.text('Add a clear exterior vehicle photo.'), findsOneWidget);
  });

  testWidgets('safety acceptance path is available in TestFlight UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            const _ProfileRepository(),
          ),
          verificationRepositoryProvider.overrideWithValue(
            const _VerificationRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VerificationHubScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Safety & reporting'), findsOneWidget);
  });

  testWidgets('verification hub shows the complete Axle label', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            const _ProfileRepository(),
          ),
          verificationRepositoryProvider.overrideWithValue(
            const _VerificationRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const VerificationHubScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Automatic check through Axle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report requires a reason before submission', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          safetyRepositoryProvider.overrideWithValue(const _SafetyRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReportUserScreen(
            targetUserId: 'test-target',
            name: 'Jordan',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();

    expect(find.text('Choose a reason to continue.'), findsOneWidget);
  });
}

class _ProfileRepository implements ProfileRepository {
  const _ProfileRepository();

  static const profile = UserProfile(
    userId: 'test-user',
    firstName: 'Maya',
    lastName: 'Chen',
    school: 'UC Santa Barbara',
    age: 20,
    gender: 'Female',
    language: 'English',
    photoUrl: 'https://example.test/profile.jpg',
    primaryRole: PrimaryRole.driver,
  );

  @override
  Future<UserProfile?> loadCurrentProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {}

  @override
  Future<void> setPrimaryRole(PrimaryRole role) async {}

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://example.test/profile.jpg';

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);
}

class _VerificationRepository implements VerificationRepository {
  const _VerificationRepository({this.summary = defaultSummary});

  static const defaultSummary = VerificationSummary(
    identity: VerificationStatus.pending,
    vehicle: VehicleProfile(
      year: 2024,
      make: 'Honda',
      model: 'CR-V',
      color: 'White',
      licensePlate: '8ABC123',
      photoUrl: 'https://example.test/vehicle.jpg',
    ),
  );

  final VerificationSummary summary;

  @override
  Future<Uri> createIdentityVerificationSession() async =>
      Uri.parse('https://verify.stripe.test');

  @override
  Future<VerificationSummary> loadCurrentVerification() async => summary;

  @override
  Future<void> saveVehicle(VehicleProfile vehicle) async {}

  @override
  Future<void> submitInsuranceDocument({
    required Uint8List bytes,
    required String contentType,
  }) async {}

  @override
  Future<String> uploadVehiclePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://example.test/vehicle.jpg';

  @override
  Stream<VerificationSummary> watchCurrentVerification() =>
      Stream.value(summary);
}

class _SafetyRepository implements SafetyRepository {
  const _SafetyRepository();

  @override
  Future<void> blockUser(String targetUserId) async {}

  @override
  Future<void> reportUser({
    required String targetUserId,
    required SafetyReportReason reason,
    String details = '',
  }) async {}
}
