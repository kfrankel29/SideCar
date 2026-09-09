import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/trip_rating_screen.dart';
import 'package:sidecar/src/features/rides/data/firebase_ride_repository.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/place_picker_sheet.dart';
import 'package:sidecar/src/core/maps/google_maps_initializer.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const visualPauseMs = int.fromEnvironment('M5_VISUAL_PAUSE_MS');

  setUpAll(initializeGoogleMapsPlatform);

  Future<void> capture(String name) async {
    if (Platform.isAndroid) {
      debugPrint('M5_FEEDBACK_SCREENSHOT_SKIPPED_ANDROID=$name');
      return;
    }
    final bytes = await binding.takeScreenshot(name);
    final file = File('${Directory.systemTemp.path}/$name.png');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('M5_FEEDBACK_SCREENSHOT=${file.path}');
    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:8766/$name'),
    );
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    client.close(force: true);
    debugPrint('M5_FEEDBACK_SCREENSHOT_HTTP=$name:${response.statusCode}');
  }

  testWidgets('rating submit and skip both return to home', (tester) async {
    final repository = _RatingRepository();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => TripRatingScreen(booking: _booking()),
                  ),
                ),
                child: const Text('Open rating'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open rating'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('driver-5')));
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(repository.ratedBookingId, 'booking-feedback');
    expect(find.text('Open rating'), findsOneWidget);

    await tester.tap(find.text('Open rating'));
    await tester.pumpAndSettle();
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Skip'))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(repository.skippedBookingId, 'booking-feedback');
    expect(find.text('Open rating'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver reimbursement card uses SideCar blue', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(_RatingRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: RateRidersScreen(bookings: [_booking()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reimbursementCard = tester.widget<Container>(
      find.byKey(const ValueKey('driver-reimbursement-card')),
    );
    expect(
      (reimbursementCard.decoration as BoxDecoration).color,
      AppColors.primary,
    );
    expect(find.text('YOU WERE REIMBURSED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'route picker uses full-screen search then restores every route control',
    (tester) async {
      final repository = _RouteRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [rideRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: PlacePickerSheet(
                title: 'Choose pickup address',
                initialQuery: '',
                rideId: 'ride-feedback',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mapFinder = find.byKey(const ValueKey('native-google-route-map'));
      final map = tester.widget<GoogleMap>(mapFinder);
      expect(tester.getSize(mapFinder).height, 300);
      expect(map.zoomGesturesEnabled, isTrue);
      expect(map.scrollGesturesEnabled, isTrue);
      expect(map.rotateGesturesEnabled, isTrue);
      expect(map.tiltGesturesEnabled, isTrue);
      expect(map.onTap, isNotNull);
      expect(map.onLongPress, isNotNull);
      expect(map.polylines, hasLength(1));
      expect(map.polylines.single.points, hasLength(3));
      expect(map.markers, hasLength(2));
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);

      expect(repository.requestedGasStations, isFalse);
      expect(find.text('Feedback Test Gas'), findsNothing);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'San Jose');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repository.requestedGasStations, isFalse);
      expect(repository.gasStationQuery, isEmpty);
      expect(mapFinder, findsNothing);
      expect(find.text('Choose pickup address'), findsNothing);
      expect(find.text('Show gas stations'), findsNothing);
      expect(find.text('Use this address'), findsNothing);
      expect(find.text('Feedback Test Gas'), findsNothing);
      expect(find.text('San Jose'), findsWidgets);
      expect(find.text('San Jose'), findsNWidgets(2));
      expect(find.text('San Jose Airport'), findsOneWidget);
      expect(find.text('San Jose State University'), findsOneWidget);
      expect(find.text('Fourth search result'), findsOneWidget);
      await capture('m7-address-search-results');
      await tester.tap(find.text('San Jose Airport'));
      await tester.pumpAndSettle();
      expect(mapFinder, findsOneWidget);
      var updatedMap = tester.widget<GoogleMap>(mapFinder);
      expect(updatedMap.markers, hasLength(7));
      expect(
        updatedMap.markers.any(
          (marker) => marker.markerId.value.contains('search-0-san-jose'),
        ),
        isTrue,
      );
      expect(find.text('Show gas stations'), findsOneWidget);
      expect(find.text('Feedback Test Gas'), findsNothing);

      await tester.tap(find.text('Show gas stations'));
      await tester.pumpAndSettle();
      expect(repository.requestedGasStations, isTrue);
      expect(repository.gasStationRequestCount, 1);
      expect(repository.gasStationQuery, 'San Jose Airport');
      updatedMap = tester.widget<GoogleMap>(mapFinder);
      expect(updatedMap.markers, hasLength(11));
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(find.text('Gas stations near San Jose Airport'), findsOneWidget);
      expect(find.text('Feedback Test Gas'), findsOneWidget);
      expect(find.text('Second Test Gas'), findsOneWidget);
      expect(find.text('Third Test Gas'), findsOneWidget);
      expect(find.text('Hidden Test Gas'), findsNothing);
      if (visualPauseMs > 0) {
        debugPrint('M5_FEEDBACK_VISUAL_PAUSE=$visualPauseMs');
        await Future<void>.delayed(Duration(milliseconds: visualPauseMs));
        await tester.pump();
      }
      await capture('m7-address-gas-stations');

      final gasMarker = updatedMap.markers.firstWhere(
        (marker) => marker.markerId.value.contains('gas-feedback'),
      );
      gasMarker.onTap?.call();
      await tester.pumpAndSettle();
      final queryField = tester.widget<TextField>(find.byType(TextField));
      expect(queryField.controller?.text, 'Feedback Test Gas, San Jose, CA');
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('use-selected-address')))
            .dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('show-gas-stations'))).dy,
        ),
      );
      final gasRequestsBeforeSecondSearch = repository.gasStationRequestCount;

      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final cityField = tester.widget<TextField>(find.byType(TextField));
      cityField.controller!
        ..text = 'San Mateo'
        ..selection = const TextSelection.collapsed(offset: 9);
      cityField.onChanged?.call('San Mateo');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repository.gasStationRequestCount, gasRequestsBeforeSecondSearch);
      expect(mapFinder, findsNothing);
      await tester.tap(find.text('San Mateo').last);
      await tester.pumpAndSettle();
      var sanMateoMap = tester.widget<GoogleMap>(mapFinder);
      expect(
        sanMateoMap.markers.any(
          (marker) => marker.markerId.value.contains('gas-san-mateo'),
        ),
        isFalse,
      );
      expect(find.text('Show gas stations'), findsOneWidget);

      await tester.tap(find.text('Show gas stations'));
      await tester.pumpAndSettle();
      expect(
        repository.gasStationRequestCount,
        gasRequestsBeforeSecondSearch + 1,
      );
      expect(repository.gasStationQuery, 'San Mateo');
      sanMateoMap = tester.widget<GoogleMap>(mapFinder);
      expect(
        sanMateoMap.markers.any(
          (marker) => marker.markerId.value.contains('gas-san-mateo'),
        ),
        isTrue,
      );
      expect(
        sanMateoMap.markers.any(
          (marker) => marker.markerId.value.contains('gas-feedback'),
        ),
        isFalse,
      );
      expect(find.text('Gas stations near San Mateo'), findsOneWidget);
      expect(find.text('San Mateo Route Gas'), findsOneWidget);

      updatedMap.onTap?.call(const LatLng(37.335, -121.89));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.text('Tapped map address'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('post ride address search shows only autocomplete results', (
    tester,
  ) async {
    final repository = _RouteRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rideRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: PlacePickerSheet(title: 'Departure city', initialQuery: ''),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'San Jose');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Search results'), findsOneWidget);
    expect(find.text('San Jose'), findsNWidgets(2));
    expect(find.text('San Jose Airport'), findsOneWidget);
    expect(find.text('San Jose State University'), findsOneWidget);
    expect(find.text('Fourth search result'), findsOneWidget);
    expect(find.text('Departure city'), findsNothing);
    expect(find.byKey(const ValueKey('native-google-route-map')), findsNothing);
    expect(find.text('Show gas stations'), findsNothing);
    expect(find.text('Use this address'), findsNothing);
    expect(repository.requestedGasStations, isFalse);
    expect(repository.gasStationRequestCount, 0);
    expect(tester.takeException(), isNull);
  });
}

class _RatingRepository extends UnavailableBookingRepository {
  String? ratedBookingId;
  String? skippedBookingId;

  @override
  Future<void> dismissTripRating(String bookingId) async {
    skippedBookingId = bookingId;
  }

  @override
  Future<void> dismissRiderRatings(List<String> bookingIds) async {}

  @override
  Future<void> rateTrip({
    required String bookingId,
    required int driverRating,
    required int tripRating,
    String comment = '',
  }) async {
    ratedBookingId = bookingId;
  }
}

class _RouteRepository extends UnavailableRideRepository {
  bool requestedGasStations = false;
  int gasStationRequestCount = 0;
  String gasStationQuery = '';

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      query.toLowerCase().contains('san mateo')
      ? _sanMateoSearchPlaces
      : _sanJoseSearchPlaces;

  @override
  Future<RideStopPickerContext> getRideStopPickerContext(
    String rideId, {
    String selectedPlaceId = '',
    List<String> searchPlaceIds = const [],
    bool includeGasStations = false,
    String gasStationQuery = '',
    double? gasStationLatitude,
    double? gasStationLongitude,
  }) async {
    requestedGasStations = includeGasStations;
    if (includeGasStations) gasStationRequestCount += 1;
    this.gasStationQuery = gasStationQuery;
    return RideStopPickerContext(
      mapPreviewUrl: '',
      routePoints: const [
        RideCoordinate(latitude: 37.7749, longitude: -122.4194),
        RideCoordinate(latitude: 37.3382, longitude: -121.8863),
        RideCoordinate(latitude: 34.4208, longitude: -119.6982),
      ],
      mapCenterLatitude: 36.10,
      mapCenterLongitude: -121.10,
      mapZoom: 10,
      mapWidth: 640,
      mapHeight: 352,
      gasStations: includeGasStations
          ? gasStationQuery.toLowerCase().contains('san mateo')
                ? const [
                    RidePlacePrediction(
                      placeId: 'gas-san-mateo',
                      displayName: 'San Mateo Route Gas, San Mateo, CA',
                      mainText: 'San Mateo Route Gas',
                      secondaryText: 'San Mateo, CA · 0.4 mi from route',
                      latitude: 37.5630,
                      longitude: -122.3255,
                    ),
                  ]
                : const [
                    RidePlacePrediction(
                      placeId: 'gas-feedback',
                      displayName: 'Feedback Test Gas, San Jose, CA',
                      mainText: 'Feedback Test Gas',
                      secondaryText: 'San Jose, CA · 0.3 mi from route',
                      latitude: 37.3385,
                      longitude: -121.8870,
                    ),
                    RidePlacePrediction(
                      placeId: 'gas-2',
                      displayName: 'Second Test Gas, San Jose, CA',
                      mainText: 'Second Test Gas',
                      secondaryText: 'San Jose, CA · 0.4 mi from route',
                      latitude: 37.3390,
                      longitude: -121.8860,
                    ),
                    RidePlacePrediction(
                      placeId: 'gas-3',
                      displayName: 'Third Test Gas, San Jose, CA',
                      mainText: 'Third Test Gas',
                      secondaryText: 'San Jose, CA · 0.5 mi from route',
                      latitude: 37.3370,
                      longitude: -121.8850,
                    ),
                    RidePlacePrediction(
                      placeId: 'gas-4',
                      displayName: 'Hidden Test Gas, San Jose, CA',
                      mainText: 'Hidden Test Gas',
                      secondaryText: 'San Jose, CA · 0.8 mi from route',
                      latitude: 37.3360,
                      longitude: -121.8840,
                    ),
                  ]
          : const [],
      searchResults: [..._sanJoseSearchPlaces, ..._sanMateoSearchPlaces]
          .where((place) => searchPlaceIds.contains(place.placeId))
          .toList(growable: false),
    );
  }

  @override
  Future<RidePlacePrediction> resolveRideStopPin(
    String rideId, {
    required double latitude,
    required double longitude,
  }) async => RidePlacePrediction(
    placeId: 'tapped-map-address',
    displayName: 'Tapped map address, San Jose, CA',
    mainText: 'Tapped map address',
    secondaryText: 'San Jose, CA',
    latitude: latitude,
    longitude: longitude,
  );
}

const _sanJoseSearchPlaces = [
  RidePlacePrediction(
    placeId: 'san-jose',
    displayName: 'San Jose, CA, USA',
    mainText: 'San Jose',
    secondaryText: 'CA, USA',
    latitude: 37.3382,
    longitude: -121.8863,
  ),
  RidePlacePrediction(
    placeId: 'san-jose-airport',
    displayName: 'San Jose Airport, CA, USA',
    mainText: 'San Jose Airport',
    secondaryText: 'San Jose, CA',
    latitude: 37.3639,
    longitude: -121.9289,
  ),
  RidePlacePrediction(
    placeId: 'san-jose-state',
    displayName: 'San Jose State University, CA, USA',
    mainText: 'San Jose State University',
    secondaryText: 'San Jose, CA',
    latitude: 37.3352,
    longitude: -121.8811,
  ),
  RidePlacePrediction(
    placeId: 'fourth-result',
    displayName: 'Fourth search result, San Jose, CA',
    mainText: 'Fourth search result',
    secondaryText: 'San Jose, CA',
    latitude: 37.32,
    longitude: -121.9,
  ),
];

const _sanMateoSearchPlaces = [
  RidePlacePrediction(
    placeId: 'san-mateo',
    displayName: 'San Mateo, CA, USA',
    mainText: 'San Mateo',
    secondaryText: 'CA, USA',
    latitude: 37.5630,
    longitude: -122.3255,
  ),
  RidePlacePrediction(
    placeId: 'san-mateo-event-center',
    displayName: 'San Mateo County Event Center, San Mateo, CA',
    mainText: 'San Mateo County Event Center',
    secondaryText: 'San Mateo, CA',
    latitude: 37.5467,
    longitude: -122.3019,
  ),
  RidePlacePrediction(
    placeId: 'san-mateo-county',
    displayName: 'San Mateo County, CA, USA',
    mainText: 'San Mateo County',
    secondaryText: 'CA, USA',
    latitude: 37.4337,
    longitude: -122.4014,
  ),
];

SeatBooking _booking() => SeatBooking.fromJson({
  'id': 'booking-feedback',
  'rideId': 'ride-feedback',
  'riderId': 'rider-feedback',
  'riderName': 'Maya Chen',
  'riderInitials': 'MC',
  'riderPhotoUrl': '',
  'driverId': 'driver-feedback',
  'driverName': 'Jordan T.',
  'driverPhotoUrl': '',
  'status': 'completed',
  'originName': 'Isla Vista',
  'destinationName': 'Palo Alto',
  'departureAt': '2026-08-15T17:00:00.000Z',
  'baseFareCents': 5000,
  'serviceFeeCents': 400,
  'processingFeeCents': 192,
  'totalCents': 5592,
});
