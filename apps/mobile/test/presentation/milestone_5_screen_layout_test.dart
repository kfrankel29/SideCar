import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/trip_rating_screen.dart';
import 'package:sidecar/src/features/messaging/domain/conversation_models.dart';
import 'package:sidecar/src/features/messaging/domain/messaging_repository.dart';
import 'package:sidecar/src/features/messaging/presentation/messaging_screens.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/data/firebase_ride_repository.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/place_picker_sheet.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/features/safety/presentation/safety_screens.dart';
import 'package:sidecar/src/theme/app_theme.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('message inbox shows ride context and unread state', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) => Stream.value(_profile()),
          ),
          messagingRepositoryProvider.overrideWithValue(_MessagingFake()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: MessageInboxScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Jordan T.'), findsOneWidget);
    expect(find.text('Ride'), findsOneWidget);
    expect(find.text('I will meet you by the library.'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat separates incoming and outgoing messages and sends', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final repository = _MessagingFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) => Stream.value(_profile()),
          ),
          messagingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ChatScreen(conversationId: 'booking-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jordan T.'), findsOneWidget);
    expect(find.text("Sat's trip · IV → Palo Alto"), findsOneWidget);
    expect(find.text('See you soon.'), findsOneWidget);
    expect(find.text('I will meet you by the library.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Thanks!');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(repository.sentText, 'Thanks!');
    expect(repository.markedRead, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rider submits the Figma driver rating flow', (tester) async {
    await setPhoneSize(tester);
    final repository = _RatingFake();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('Home destination'),
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => TripRatingScreen(booking: _booking()),
                      ),
                    ),
                    child: const Text('Open rating'),
                  ),
                ),
              ],
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
    expect(find.text('Home safe'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('driver-5')));
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();

    expect(repository.ratedTrip, 'booking-1');
    expect(repository.driverRating, 5);
    expect(repository.tripRating, 5);
    expect(find.text('Home destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rider skips rating and returns home', (tester) async {
    await setPhoneSize(tester);
    final repository = _RatingFake();
    final router = GoRouter(
      initialLocation: '/rating',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home destination')),
        ),
        GoRoute(
          path: '/rating',
          builder: (_, _) => TripRatingScreen(booking: _booking()),
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

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(repository.skippedTrip, 'booking-1');
    expect(find.text('Home destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver rates every rider after completing a trip', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final repository = _RatingFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: RateRidersScreen(bookings: [_booking()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rate your riders'), findsOneWidget);
    expect(find.text('Nice drive'), findsOneWidget);
    expect(find.text('Maya C.'), findsOneWidget);
    final reimbursementCard = tester.widget<Container>(
      find.byKey(const ValueKey('driver-reimbursement-card')),
    );
    expect(
      (reimbursementCard.decoration as BoxDecoration).color,
      AppColors.primary,
    );
    await tester.tap(find.text('Easy pickup'));
    await tester.tap(find.byKey(const ValueKey('rider-booking-1-5')));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(repository.ratedRider, 'booking-1');
    expect(repository.riderRating, 5);
    expect(repository.riderComment, 'Easy pickup');
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver can persistently skip rider ratings', (tester) async {
    await setPhoneSize(tester);
    final repository = _RatingFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bookingRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: RateRidersScreen(bookings: [_booking()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(repository.skippedRiderBookings, ['booking-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked users can be unblocked from the safety list', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final repository = _SafetyFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [safetyRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SafetyToolsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blocked users'), findsOneWidget);
    expect(find.text('Jordan T.'), findsOneWidget);
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();

    expect(repository.unblockedUserId, 'driver-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('report user presents every approved safety reason', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [safetyRepositoryProvider.overrideWithValue(_SafetyFake())],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReportUserScreen(
            targetUserId: 'driver-1',
            name: 'Jordan T.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report Jordan T.'), findsOneWidget);
    for (final reason in SafetyReportReason.values) {
      expect(find.text(reason.title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('report submission matches the final confirmation state', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [safetyRepositoryProvider.overrideWithValue(_SafetyFake())],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ReportUserScreen(
            targetUserId: 'driver-1',
            name: 'Jordan',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unsafe behavior'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Report submitted'), findsOneWidget);
    expect(
      find.text(
        'Our team reviews reports within 24 hours.\nWe may follow up by email.',
      ),
      findsOneWidget,
    );
    expect(find.text('Private by default'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Also block Jordan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route stop picker loads Google route gas stations on request', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final repository = _RoutePickerFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rideRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: PlacePickerSheet(
              title: 'Choose pickup address',
              initialQuery: '',
              rideId: 'ride-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final map = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('interactive-route-map')),
    );
    expect(map.minScale, 1);
    expect(map.maxScale, greaterThanOrEqualTo(5));
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('interactive-route-map')))
          .height,
      greaterThanOrEqualTo(300),
    );
    expect(find.text('Show gas stations'), findsNothing);
    expect(find.text('Central Coast Gas'), findsNothing);
    expect(find.text('Use this address'), findsNothing);
    expect(repository.requestedGasStations, isFalse);

    await tester.tap(find.byKey(const ValueKey('route-stop-map')));
    await tester.pumpAndSettle();

    expect(find.text('Show gas stations'), findsOneWidget);
    await tester.tap(find.text('Show gas stations'));
    await tester.pumpAndSettle();

    expect(repository.requestedGasStations, isTrue);
    expect(repository.gasStationRequestCount, 1);
    expect(find.text('Reload gas stations in this map area'), findsOneWidget);
    expect(find.text('Gas stations near Dropped pin'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Central Coast Gas'), findsOneWidget);
    await tester.tap(find.text('Central Coast Gas'));
    await tester.pumpAndSettle();

    expect(repository.selectedPlaceId, 'gas-1');
    expect(find.text('Use this address'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    final requestsBeforeReload = repository.gasStationRequestCount;
    await tester.tap(find.text('Reload gas stations in this map area'));
    await tester.pumpAndSettle();
    expect(repository.gasStationRequestCount, requestsBeforeReload + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route stop picker resolves a dropped map pin', (tester) async {
    await setPhoneSize(tester);
    final repository = _RoutePickerFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rideRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: PlacePickerSheet(
              title: 'Choose pickup address',
              initialQuery: '',
              rideId: 'ride-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('route-stop-map')));
    await tester.pumpAndSettle();

    expect(repository.resolvedLatitude, closeTo(34.42, 0.01));
    expect(repository.resolvedLongitude, closeTo(-119.70, 0.01));
    expect(repository.selectedPlaceId, 'pin-1');
    expect(find.text('Dropped pin'), findsOneWidget);
    expect(find.text('Use this address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route stop picker uses a full results view while typing', (
    tester,
  ) async {
    await setPhoneSize(tester);
    tester.view.physicalSize = const Size(375, 2000);
    final repository = _RoutePickerFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rideRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: PlacePickerSheet(
              title: 'Choose pickup address',
              initialQuery: '',
              rideId: 'ride-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'palo alto');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.searchQuery, 'palo alto');
    expect(repository.requestedSearchPlaceIds, isEmpty);
    expect(find.byKey(const ValueKey('interactive-route-map')), findsNothing);
    expect(find.text('Choose pickup address'), findsNothing);
    expect(find.text('Palo Alto'), findsOneWidget);
    expect(find.text('Palo Alto Junior Museum'), findsOneWidget);
    expect(find.text('Palo Alto Caltrain'), findsOneWidget);
    expect(find.text('Palo Alto Airport'), findsOneWidget);
    expect(find.text('Show gas stations'), findsNothing);
    expect(find.text('Use this address'), findsNothing);
    expect(find.text('Central Coast Gas'), findsNothing);
    expect(find.text('Second Gas'), findsNothing);
    expect(find.text('Third Gas'), findsNothing);
    expect(find.text('Hidden Gas'), findsNothing);
    expect(repository.requestedGasStations, isFalse);

    await tester.tap(find.text('Palo Alto Airport'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('interactive-route-map')), findsOneWidget);
    expect(find.text('Use this address'), findsOneWidget);
    expect(find.text('Show gas stations'), findsOneWidget);
    expect(find.text('Central Coast Gas'), findsNothing);

    await tester.tap(find.text('Show gas stations'));
    await tester.pumpAndSettle();

    expect(repository.requestedGasStations, isTrue);
    expect(find.text('Central Coast Gas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route place search keeps keyboard focus as results update', (
    tester,
  ) async {
    await setPhoneSize(tester);
    tester.view.physicalSize = const Size(375, 2000);
    final repository = _RoutePickerFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rideRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: PlacePickerSheet(
              title: 'Where are you leaving from?',
              initialQuery: '',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchField = find.byKey(const ValueKey('place-search-field'));
    await tester.enterText(searchField, 'is');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    var editable = tester.widget<EditableText>(
      find.descendant(of: searchField, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isRegistered, isTrue);
    expect(find.text('Search results'), findsOneWidget);

    await tester.enterText(searchField, 'isla');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    editable = tester.widget<EditableText>(
      find.descendant(of: searchField, matching: find.byType(EditableText)),
    );
    expect(repository.searchQuery, 'isla');
    expect(editable.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isRegistered, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('conversation visibility is scoped to the blocking user', () {
    final conversation = _MessagingFake().conversation;
    final hidden = RideConversation(
      id: conversation.id,
      bookingId: conversation.bookingId,
      rideId: conversation.rideId,
      participantIds: conversation.participantIds,
      participantNames: conversation.participantNames,
      participantInitials: conversation.participantInitials,
      participantPhotoUrls: conversation.participantPhotoUrls,
      lastMessage: conversation.lastMessage,
      lastMessageAt: conversation.lastMessageAt,
      unreadCounts: conversation.unreadCounts,
      hiddenFor: const {'rider-1': true},
      tripLabel: conversation.tripLabel,
    );

    expect(hidden.isHiddenFor('rider-1'), isTrue);
    expect(hidden.isHiddenFor('driver-1'), isFalse);
  });
}

class _MessagingFake implements MessagingRepository {
  String? sentText;
  bool markedRead = false;

  RideConversation get conversation => RideConversation(
    id: 'booking-1',
    bookingId: 'booking-1',
    rideId: 'ride-1',
    participantIds: const ['rider-1', 'driver-1'],
    participantNames: const {'rider-1': 'Maya Chen', 'driver-1': 'Jordan T.'},
    participantInitials: const {'rider-1': 'MC', 'driver-1': 'JT'},
    participantPhotoUrls: const {'rider-1': '', 'driver-1': ''},
    lastMessage: 'I will meet you by the library.',
    lastMessageAt: DateTime(2026, 8, 15, 10, 42),
    unreadCounts: const {'rider-1': 1, 'driver-1': 0},
    hiddenFor: const {},
    tripLabel: 'Isla Vista → Palo Alto',
    departureAt: DateTime(2026, 8, 15, 15),
  );

  @override
  Future<void> markRead(String conversationId) async => markedRead = true;

  @override
  Future<RideConversation> openBookingConversation(String bookingId) async =>
      conversation;

  @override
  Future<RideConversation> openDirectConversation(String userId) async =>
      conversation;

  @override
  Future<void> sendMessage(String conversationId, String text) async =>
      sentText = text;

  @override
  Stream<List<RideConversation>> watchConversations() =>
      Stream.value([conversation]);

  @override
  Stream<List<ConversationMessage>> watchMessages(String conversationId) =>
      Stream.value([
        ConversationMessage(
          id: 'message-2',
          senderId: 'driver-1',
          text: 'I will meet you by the library.',
          createdAt: DateTime(2026, 8, 15, 10, 42),
        ),
        ConversationMessage(
          id: 'message-1',
          senderId: 'rider-1',
          text: 'See you soon.',
          createdAt: DateTime(2026, 8, 15, 10, 40),
        ),
      ]);
}

class _RatingFake extends UnavailableBookingRepository {
  String? ratedTrip;
  int? driverRating;
  int? tripRating;
  String? ratedRider;
  int? riderRating;
  String? riderComment;
  String? skippedTrip;
  List<String>? skippedRiderBookings;

  @override
  Future<void> dismissTripRating(String bookingId) async {
    skippedTrip = bookingId;
  }

  @override
  Future<void> dismissRiderRatings(List<String> bookingIds) async {
    skippedRiderBookings = bookingIds;
  }

  @override
  Future<void> rateTrip({
    required String bookingId,
    required int driverRating,
    required int tripRating,
    String comment = '',
  }) async {
    ratedTrip = bookingId;
    this.driverRating = driverRating;
    this.tripRating = tripRating;
  }

  @override
  Future<void> rateRider({
    required String bookingId,
    required int rating,
    String comment = '',
  }) async {
    ratedRider = bookingId;
    riderRating = rating;
    riderComment = comment;
  }
}

class _SafetyFake implements SafetyRepository {
  String? unblockedUserId;

  @override
  Future<void> blockUser(String targetUserId) async {}

  @override
  Future<bool> isBlocked(String targetUserId) async => false;

  @override
  Future<List<BlockedUser>> listBlockedUsers() async => [
    BlockedUser(
      id: 'driver-1',
      displayName: 'Jordan T.',
      initials: 'JT',
      photoUrl: '',
      blockedAt: DateTime(2026, 8, 15),
    ),
  ];

  @override
  Future<void> reportUser({
    required String targetUserId,
    required SafetyReportReason reason,
    String details = '',
  }) async {}

  @override
  Future<void> unblockUser(String targetUserId) async {
    unblockedUserId = targetUserId;
  }
}

class _RoutePickerFake extends UnavailableRideRepository {
  String selectedPlaceId = '';
  String searchQuery = '';
  bool requestedGasStations = false;
  int gasStationRequestCount = 0;
  double? resolvedLatitude;
  double? resolvedLongitude;
  List<String> requestedSearchPlaceIds = const [];

  static const places = [
    RidePlacePrediction(
      placeId: 'place-1',
      displayName: 'Palo Alto, CA',
      mainText: 'Palo Alto',
      secondaryText: 'CA, USA',
      latitude: 37.4419,
      longitude: -122.143,
    ),
    RidePlacePrediction(
      placeId: 'place-2',
      displayName: 'Palo Alto Junior Museum, CA',
      mainText: 'Palo Alto Junior Museum',
      secondaryText: 'Palo Alto, CA',
      latitude: 37.444,
      longitude: -122.14,
    ),
    RidePlacePrediction(
      placeId: 'place-3',
      displayName: 'Palo Alto Caltrain, CA',
      mainText: 'Palo Alto Caltrain',
      secondaryText: 'Palo Alto, CA',
      latitude: 37.443,
      longitude: -122.165,
    ),
    RidePlacePrediction(
      placeId: 'place-4',
      displayName: 'Palo Alto Airport, CA',
      mainText: 'Palo Alto Airport',
      secondaryText: 'Palo Alto, CA',
      latitude: 37.461,
      longitude: -122.115,
    ),
  ];

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async {
    searchQuery = query;
    return places;
  }

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
    this.selectedPlaceId = selectedPlaceId;
    requestedSearchPlaceIds = searchPlaceIds;
    requestedGasStations = includeGasStations;
    if (includeGasStations) gasStationRequestCount += 1;
    return RideStopPickerContext(
      mapPreviewUrl: '',
      mapCenterLatitude: 34.42,
      mapCenterLongitude: -119.70,
      mapZoom: 10,
      mapWidth: 640,
      mapHeight: 352,
      gasStations: includeGasStations
          ? const [
              RidePlacePrediction(
                placeId: 'gas-1',
                displayName: 'Central Coast Gas, Goleta, CA',
                mainText: 'Central Coast Gas',
                secondaryText: 'Goleta, CA · 0.4 mi from route',
              ),
              RidePlacePrediction(
                placeId: 'gas-2',
                displayName: 'Second Gas, Goleta, CA',
                mainText: 'Second Gas',
                secondaryText: 'Goleta, CA · 0.5 mi from route',
              ),
              RidePlacePrediction(
                placeId: 'gas-3',
                displayName: 'Third Gas, Goleta, CA',
                mainText: 'Third Gas',
                secondaryText: 'Goleta, CA · 0.6 mi from route',
              ),
              RidePlacePrediction(
                placeId: 'gas-4',
                displayName: 'Hidden Gas, Goleta, CA',
                mainText: 'Hidden Gas',
                secondaryText: 'Goleta, CA · 0.7 mi from route',
              ),
            ]
          : const [],
      searchResults: places
          .where((place) => searchPlaceIds.contains(place.placeId))
          .toList(growable: false),
    );
  }

  @override
  Future<RidePlacePrediction> resolveRideStopPin(
    String rideId, {
    required double latitude,
    required double longitude,
  }) async {
    resolvedLatitude = latitude;
    resolvedLongitude = longitude;
    return RidePlacePrediction(
      placeId: 'pin-1',
      displayName: 'Dropped pin, Santa Barbara, CA',
      mainText: 'Dropped pin',
      secondaryText: 'Santa Barbara, CA',
      latitude: latitude,
      longitude: longitude,
    );
  }
}

UserProfile _profile() => const UserProfile(
  userId: 'rider-1',
  firstName: 'Maya',
  lastName: 'Chen',
  school: 'UCSB',
  photoUrl: 'https://example.com/maya.jpg',
  age: 20,
  gender: 'Female',
  language: 'English',
);

SeatBooking _booking() => SeatBooking.fromJson({
  'id': 'booking-1',
  'rideId': 'ride-1',
  'riderId': 'rider-1',
  'riderName': 'Maya Chen',
  'riderInitials': 'MC',
  'riderPhotoUrl': '',
  'driverId': 'driver-1',
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
