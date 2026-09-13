import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';

const _role = String.fromEnvironment('QA_SESSION_ROLE');
const _driverEmail = String.fromEnvironment('M5_E2E_FIRST_EMAIL');
const _driverPassword = String.fromEnvironment('M5_E2E_FIRST_PASSWORD');
const _riderEmail = String.fromEnvironment('M5_E2E_SECOND_EMAIL');
const _riderPassword = String.fromEnvironment('M5_E2E_SECOND_PASSWORD');
const _routeId = String.fromEnvironment('QA_ROUTE_ID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'keeps live driver and rider map sessions active together',
    (tester) async {
      expect(_role, anyOf('driver', 'rider'));
      expect(_routeId, isNotEmpty);
      final bootstrap = await AppBootstrap.initialize().timeout(
        const Duration(seconds: 45),
      );
      expect(bootstrap.firebaseReady, isTrue);

      final isDriver = _role == 'driver';
      await bootstrap.authRepository
          .signIn(
            email: isDriver ? _driverEmail : _riderEmail,
            password: isDriver ? _driverPassword : _riderPassword,
          )
          .timeout(const Duration(seconds: 45));

      if (isDriver) {
        // Hold a real authenticated driver session open while the rider device
        // resolves its address and reads the trip's persisted station list.
        for (var attempt = 0; attempt < 18; attempt++) {
          final ride = await bootstrap.rideRepository
              .getRide(_routeId)
              .timeout(const Duration(seconds: 30));
          expect(ride.id, _routeId);
          await tester.pump(const Duration(seconds: 5));
        }
      } else {
        final matches = await bootstrap.rideRepository
            .searchPlaces('San Mateo, California')
            .timeout(const Duration(seconds: 40));
        expect(matches, isNotEmpty);
        final context = await bootstrap.rideRepository
            .getRideStopPickerContext(
              _routeId,
              selectedPlaceId: matches.first.placeId,
              includeGasStations: true,
            )
            .timeout(const Duration(seconds: 40));
        expect(context.searchResults.single.placeId, matches.first.placeId);
        expect(context.gasStations, isNotEmpty);
        await tester.pump(const Duration(seconds: 15));
      }

      await bootstrap.authRepository.signOut();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
