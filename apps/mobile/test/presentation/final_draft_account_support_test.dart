import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/features/profile/domain/account_security_repository.dart';
import 'package:sidecar/src/features/profile/presentation/account_support_screens.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('delete account requires the exact confirmation phrase', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final repository = _AccountSecurityFake();
    final router = GoRouter(
      initialLocation: '/delete',
      routes: [
        GoRoute(
          path: '/delete',
          builder: (_, _) => const DeleteAccountScreen(),
        ),
        GoRoute(
          path: AppRoutes.welcome,
          builder: (_, _) => const Scaffold(body: Text('Welcome')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountSecurityRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Delete account');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.deletedWith, 'DELETE');
    expect(find.text('Welcome'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel ride matches the Final Draft decision contract', (
    tester,
  ) async {
    await setPhoneSize(tester);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CancelRideConfirmationScreen(ride: _ride()),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this ride?'), findsOneWidget);
    expect(find.textContaining('Isla Vista → Palo Alto'), findsOneWidget);
    await tester.tap(find.text('Cancel ride'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help search and cancellation policy are complete', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const HelpFaqScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Help & FAQs'), findsOneWidget);
    expect(find.text('What happens if I cancel?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'payout');
    await tester.pump();
    expect(find.text('When do drivers receive payouts?'), findsOneWidget);
    expect(find.text('What happens if I cancel?'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('View full cancellation policy'));
    await tester.pumpAndSettle();
    expect(find.text('Free until 7 days before your ride'), findsOneWidget);
    expect(find.text('If your driver cancels'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('change password validates and submits current credentials', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final repository = _AccountSecurityFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountSecurityRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChangePasswordScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'old-password');
    await tester.enterText(fields.at(1), 'newpass1');
    await tester.enterText(fields.at(2), 'newpass1');
    await tester.pump();
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(repository.currentPassword, 'old-password');
    expect(repository.newPassword, 'newpass1');
    expect(tester.takeException(), isNull);
  });
}

class _AccountSecurityFake implements AccountSecurityRepository {
  String? currentPassword;
  String? newPassword;
  String? deletedWith;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
  }

  @override
  Future<void> deleteAccount({required String confirmation}) async {
    deletedWith = confirmation;
  }
}

Ride _ride() => Ride.fromJson({
  'id': 'ride-support',
  'driverId': 'driver-1',
  'driverName': 'Jordan Taylor',
  'driverInitials': 'JT',
  'origin': {
    'placeId': 'origin',
    'displayName': 'Isla Vista',
    'formattedAddress': 'Isla Vista, CA',
    'latitude': 34.41,
    'longitude': -119.85,
  },
  'destination': {
    'placeId': 'destination',
    'displayName': 'Palo Alto',
    'formattedAddress': 'Palo Alto, CA',
    'latitude': 37.44,
    'longitude': -122.16,
  },
  'departureAt': '2026-08-31T22:00:00.000Z',
  'status': 'published',
  'seats': 3,
  'availableSeats': 1,
  'bookedSeats': 2,
  'pricePerSeatCents': 5000,
});
