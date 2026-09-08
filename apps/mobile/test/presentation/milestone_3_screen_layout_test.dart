import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/auth/domain/account_user.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/navigation/presentation/main_tab_shell.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/profile/presentation/account_profile_screen.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_details_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_home_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_search_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_widgets.dart';
import 'package:sidecar/src/theme/app_theme.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('main tabs use the exported Final Draft Figma assets', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            role: PrimaryRole.rider,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final riderAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toList();
    expect(riderAssets, <String>[
      'assets/icons/tabs/home.png',
      'assets/icons/tabs/search.png',
      'assets/icons/tabs/rides.png',
      'assets/icons/tabs/messages.png',
      'assets/icons/tabs/profile.png',
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            role: PrimaryRole.driver,
            selectedIndex: 1,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final driverAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toList();
    expect(driverAssets[1], 'assets/icons/tabs/post.png');
    expect(find.byType(Icon), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My rides shows an update dot for ride status changes', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            role: PrimaryRole.rider,
            selectedIndex: 0,
            unreadRideUpdates: 1,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('my-rides-update-count')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation badges show message and ride counts with a 9+ cap', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MainBottomNavigation(
            role: PrimaryRole.driver,
            selectedIndex: 0,
            unreadMessages: 14,
            pendingRequests: 3,
            unreadRideUpdates: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('9+'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-rides-update-count')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search screen contains the Final Draft M3 controls', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SearchRidesScreen()),
    );

    expect(find.text('Find a ride'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Pick Up Location'), findsOneWidget);
    expect(find.text('Drop Off Location'), findsOneWidget);
    expect(find.text('UCSB / Isla Vista'), findsNothing);
    expect(find.text('San Mateo / Peninsula'), findsNothing);
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('Male drivers'), findsNothing);
    expect(find.text('2+ bags'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('4.8+ rating'), findsOneWidget);
    expect(find.text('Search rides'), findsOneWidget);
    expect(
      tester
          .widgetList<RideChoiceChip>(find.byType(RideChoiceChip))
          .where((chip) => chip.selected),
      isEmpty,
    );
    expect(find.text('Select date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post screen exposes all immutable ride fields', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const PostRideScreen()),
      ),
    );

    expect(find.text('Post a ride'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Departure City'), findsOneWidget);
    expect(find.text('Destination City'), findsOneWidget);
    expect(find.text('Select time'), findsOneWidget);
    expect(find.text('Price / seat'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    expect(find.text('4+'), findsOneWidget);
    expect(find.text('Luggage per rider'), findsOneWidget);
    expect(find.text('Repeat weekly'), findsNothing);
    expect(find.text('Women only'), findsOneWidget);
    expect(find.text('Backpack'), findsOneWidget);
    expect(find.text('1 suitcase'), findsOneWidget);
    expect(find.text('2+ bags'), findsOneWidget);
    expect(find.text('Post ride · earn ~\$0'), findsNothing);
    expect(find.text('Post ride'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Drivers must:'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Drivers must:'), findsOneWidget);
    expect(
      find.text(
        'Carry active auto insurance during the trip\n'
        'Wait 10 minutes past pickup time before marking a no-show\n'
        'A 5% platform fee is deducted from your total reimbursement.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('post screen uses keyboard time entry and 4+ seat menu', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const PostRideScreen()),
      ),
    );

    await tester.tap(find.text('4+'));
    await tester.pumpAndSettle();
    expect(find.text('4 seats'), findsOneWidget);
    expect(find.text('5 seats'), findsOneWidget);
    expect(find.text('6 seats'), findsOneWidget);
    await tester.tap(find.text('6 seats'));
    await tester.pumpAndSettle();
    expect(find.text('4+'), findsOneWidget);

    await tester.tap(find.text('Select time'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsAtLeastNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver second tab resolves to post ride, not ride details', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final container = ProviderContainer(
      overrides: [
        rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        profileRepositoryProvider.overrideWithValue(_ProfileRepository()),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.go(AppRoutes.home);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ride-nav-1')));
    await tester.pumpAndSettle();

    expect(find.byType(PostRideScreen), findsOneWidget);
    expect(find.byType(RideDetailsScreen), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.postRide);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pickup and drop-off open their own Google Places pickers', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SearchRidesScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Pick Up Location'));
    await tester.pumpAndSettle();
    expect(find.text('Pickup area'), findsOneWidget);
    Navigator.of(tester.element(find.text('Pickup area'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drop Off Location'));
    await tester.pumpAndSettle();
    expect(find.text('Drop-off area'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Final Draft filters start empty and can be selected', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SearchRidesScreen()),
    );

    await tester.tap(find.text('Women only'));
    await tester.tap(find.text('2+ bags'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4.8+ rating'));
    await tester.pump();

    final selected = tester
        .widgetList<RideChoiceChip>(find.byType(RideChoiceChip))
        .where((chip) => chip.selected)
        .map((chip) => chip.label)
        .toSet();
    expect(selected, containsAll(<String>{'2+ bags', '4.8+ rating'}));
    expect(find.text('Language'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route preview never paints a fabricated route', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: RideMapPreview()),
      ),
    );

    expect(find.byType(RideMapPreview), findsOneWidget);
    expect(find.text('Map unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ride cards render the driver profile photo', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: RideCard(ride: _ride)),
      ),
    );

    final avatar = tester.widget<RideAvatar>(find.byType(RideAvatar));
    expect(avatar.photoUrl, 'https://example.test/driver.jpg');
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text(formatShortDate(_ride.departureAt)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M7 cards grow and wrap long locations instead of truncating', (
    tester,
  ) async {
    await setPhoneSize(tester);
    const longOrigin =
        'Santa Barbara Student Recreation Center and Community Hall';
    const longDestination =
        'Los Angeles International Airport Terminal Seven Departures';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  RideSummaryCard(
                    key: ValueKey('short-card'),
                    origin: 'Isla Vista',
                    destination: 'Palo Alto',
                    dateLabel: 'Fri, Jul 10',
                    timeLabel: '3:00 PM',
                    priceLabel: '\$56',
                    bookedLabel: '2/3 booked',
                  ),
                  SizedBox(height: 12),
                  RideSummaryCard(
                    key: ValueKey('long-card'),
                    origin: longOrigin,
                    destination: longDestination,
                    dateLabel: 'Friday, September 18',
                    timeLabel: '10:30 PM',
                    priceLabel: '\$56',
                    bookedLabel: '2/3 booked',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(longOrigin), findsOneWidget);
    expect(find.text(longDestination), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('long-card'))).height,
      greaterThan(
        tester.getSize(find.byKey(const ValueKey('short-card'))).height,
      ),
    );
    for (final label in [longOrigin, longDestination]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('M7 cards abbreviate UCSB and keep actions inside the card', (
    tester,
  ) async {
    expect(abbreviateRidePlaceName('UC Santa Barbara'), 'UCSB');
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: RideSummaryCard(
              origin: 'University of California, Santa Barbara',
              destination: 'Palo Alto',
              dateLabel: 'Fri, Jul 10',
              timeLabel: '3:00 PM',
              priceLabel: '\$56',
              bookedLabel: '2/3 booked',
              footer: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: null,
                      child: Text('Cancel ride'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: null,
                      child: Text('Share link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('UCSB'), findsOneWidget);
    expect(find.text('University of California, Santa Barbara'), findsNothing);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route preview shows loading without retaining another map', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RideMapPreview(
            mapPreviewUrl: 'https://example.invalid/route-map.png',
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.useOldImageOnUrlChange, isFalse);
    expect(image.placeholder, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ride map extends under status area while controls stay clear', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _RiderAuthRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 812),
              padding: EdgeInsets.only(top: 59, bottom: 34),
              viewPadding: EdgeInsets.only(top: 59, bottom: 34),
            ),
            child: child!,
          ),
          home: const RideDetailsScreen(rideId: 'layout-ride'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mapRect = tester.getRect(find.byType(RideMapPreview));
    final backRect = tester.getRect(find.byTooltip('Back'));
    expect(mapRect.top, 0);
    expect(mapRect.height, closeTo(206.66, 0.1));
    expect(backRect.top, greaterThanOrEqualTo(59));
    expect(backRect.bottom, lessThan(mapRect.bottom));
  });

  testWidgets('driver home route card fits a production phone viewport', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
          profileRepositoryProvider.overrideWithValue(_ProfileRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RideHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your upcoming ride'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver home card matches the M7 route-first format', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
          profileRepositoryProvider.overrideWithValue(_ProfileRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const RideHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.getRect(
      find.byKey(const ValueKey('driver-upcoming-card-layout-ride')),
    );
    final date = tester.getRect(
      find.byKey(const ValueKey('driver-upcoming-layout-ride-date')),
    );
    final time = tester.getRect(
      find.byKey(const ValueKey('driver-upcoming-layout-ride-time')),
    );
    final price = tester.getRect(
      find.byKey(const ValueKey('driver-upcoming-layout-ride-price')),
    );
    final origin = tester.getRect(
      find.byKey(const ValueKey('driver-upcoming-layout-ride-origin')),
    );
    final destination = tester.getRect(
      find.byKey(const ValueKey('driver-upcoming-layout-ride-destination')),
    );
    final booked = tester.getRect(
      find.byKey(const ValueKey('driver-upcoming-layout-ride-booked')),
    );
    final dateText = tester.widget<Text>(
      find.byKey(const ValueKey('driver-upcoming-layout-ride-date')),
    );

    expect(card.left, closeTo(24, 0.1));
    expect(card.width, closeTo(327, 0.1));
    expect(card.height, greaterThan(140));
    expect(origin.top, lessThan(date.top));
    expect(destination.top, lessThan(date.top));
    expect(date.left, closeTo(origin.left, 0.1));
    expect(time.left, closeTo(date.left, 0.1));
    expect(price.right, closeTo(destination.right, 0.1));
    expect(booked.right, closeTo(price.right, 0.1));
    expect(dateText.data, formatShortDate(_ride.departureAt));
    expect(dateText.data, isNot(contains(',,')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile settings preserves the recovered card layout', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) => Stream.value(
              _ProfileRepository.profile.copyWith(
                primaryRole: PrimaryRole.rider,
              ),
            ),
          ),
          currentVerificationProvider.overrideWith(
            (ref) => Stream.value(
              const VerificationSummary(identity: VerificationStatus.verified),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 812),
              padding: EdgeInsets.only(top: 47, bottom: 34),
              viewPadding: EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: child!,
          ),
          home: const Scaffold(body: AccountProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Profile')).dy, closeTo(65, 1));
    expect(find.text('Use SideCar as'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Personal information'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Payment methods'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Support and safety'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Support and safety'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-log-out')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('profile-log-out')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('driver ride management uses requests and immutable rides', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const MyRidesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Recurring'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(FinalDraftAssetIcon), findsNothing);

    final origin = find.text('UCSB');
    final destination = find.text('San Francisco International Airport');
    expect(origin, findsOneWidget);
    expect(destination, findsOneWidget);
    expect(
      tester.getCenter(origin).dy,
      closeTo(tester.getCenter(destination).dy, 1),
    );

    final cancelButton = find.widgetWithText(FilledButton, 'Cancel ride');
    final shareButton = find.widgetWithText(FilledButton, 'Share link');
    expect(tester.getSize(cancelButton).height, closeTo(34, 1));
    expect(tester.getSize(shareButton).height, closeTo(34, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'results identify closest rides when the requested day is empty',
    (tester) async {
      await setPhoneSize(tester);
      final selectedDate = DateUtils.dateOnly(DateTime.now());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: SearchResultsScreen(
              criteria: RideSearchCriteria(
                originQuery: 'UCSB',
                destinationQuery: 'SFO',
                pickupPlaceId: 'pickup',
                dropoffPlaceId: 'dropoff',
                startAt: selectedDate,
                endAt: selectedDate.add(const Duration(days: 1)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Closest available'), findsOneWidget);
      expect(find.text('Soonest'), findsOneWidget);
      expect(find.text('Top rated'), findsOneWidget);
      expect(find.text('SUV'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a driver manages their own ride instead of requesting a seat', (
    tester,
  ) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const _RideOwnerAuthRepository(),
          ),
          rideRepositoryProvider.overrideWithValue(_PlacesOnlyRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RideDetailsScreen(rideId: 'layout-ride'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit ride'), findsNothing);
    expect(find.text('Cancel ride'), findsOneWidget);
    expect(find.text('Your ride'), findsOneWidget);
    expect(find.byType(RideMapPreview), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Start trip'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Start trip'), findsOneWidget);
    expect(find.text('per seat'), findsOneWidget);
    expect(find.text('Luggage per rider'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Request seat'), findsNothing);
    expect(find.text('Pick your seat'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _PlacesOnlyRepository implements RideRepository {
  @override
  void invalidateRide(String rideId) {}

  @override
  Future<void> cancelRide(String rideId) async {}

  @override
  Future<List<RidePlacePrediction>> searchPlaces(String query) async =>
      const [];

  @override
  Future<Ride> createRide(RideDraft draft) => throw UnimplementedError();

  @override
  Future<Ride> getRide(String rideId) async => _ride;

  @override
  Future<RideStopPickerContext> getRideStopPickerContext(
    String rideId, {
    String selectedPlaceId = '',
    List<String> searchPlaceIds = const [],
    bool includeGasStations = false,
    String gasStationQuery = '',
    double? gasStationLatitude,
    double? gasStationLongitude,
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
  Future<List<Ride>> listLeavingSoon({bool forceRefresh = false}) async => [
    _ride,
  ];

  @override
  Future<List<Ride>> listMyRides({bool forceRefresh = false}) async => [_ride];

  @override
  Future<List<Ride>> searchRides(RideSearchCriteria criteria) async => [_ride];

  @override
  Future<Ride> updateRide(RideUpdate update) => throw UnimplementedError();
}

class _RideOwnerAuthRepository implements AuthRepository {
  const _RideOwnerAuthRepository();

  static const _user = AccountUser(
    id: 'driver',
    email: 'driver@ucsb.edu',
    emailVerified: true,
  );

  @override
  AccountUser? get currentUser => _user;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(_user);

  @override
  Future<AccountUser?> validateCurrentSession() async => _user;

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
    bool acceptedLegalTerms = false,
    bool confirmedAge18 = false,
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
  Future<AccountUser> signInWithGoogle({
    bool acceptedLegalTerms = false,
    bool confirmedAge18 = false,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> verifyEmailCode(String code) => throw UnimplementedError();

  @override
  Future<String> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();
}

class _RiderAuthRepository extends _RideOwnerAuthRepository {
  const _RiderAuthRepository();

  static const _rider = AccountUser(
    id: 'rider',
    email: 'rider@ucsb.edu',
    emailVerified: true,
  );

  @override
  AccountUser? get currentUser => _rider;

  @override
  Stream<AccountUser?> authStateChanges() => Stream.value(_rider);

  @override
  Future<AccountUser?> validateCurrentSession() async => _rider;
}

final _ride = Ride.fromJson({
  'id': 'layout-ride',
  'driverId': 'driver',
  'driverName': 'SideCar Driver',
  'driverInitials': 'SD',
  'driverPhotoUrl': 'https://example.test/driver.jpg',
  'driverGender': 'Male',
  'driverRating': 4.9,
  'driverTrips': 10,
  'vehicle': {
    'year': 2021,
    'makeAndModel': 'Toyota Prius',
    'color': 'White',
    'photoUrl': '',
  },
  'origin': {
    'displayName': 'University of California, Santa Barbara',
    'latitude': 34.414,
    'longitude': -119.8489,
  },
  'destination': {
    'displayName': 'San Francisco International Airport',
    'latitude': 37.6213,
    'longitude': -122.379,
  },
  'departureAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
  'distanceMiles': 320,
  'durationSeconds': 18000,
  'seatsTotal': 3,
  'seatsAvailable': 3,
  'pricePerSeatCents': 5000,
  'maximumPriceCents': 9000,
  'luggageAllowance': 'one_suitcase',
  'genderRestriction': 'any',
  'status': 'published',
  'shareUrl': 'https://sidecar-fb0e7.web.app/ride/layout-ride',
});

class _ProfileRepository implements ProfileRepository {
  static const profile = UserProfile(
    userId: 'driver',
    firstName: 'SideCar',
    lastName: 'Driver',
    school: 'UCSB',
    photoUrl: 'photo',
    age: 24,
    gender: 'Male',
    language: 'English',
    primaryRole: PrimaryRole.driver,
  );

  @override
  Future<UserProfile?> loadCurrentProfile() async => profile;

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);

  @override
  Future<void> saveProfile(UserProfile profile) => throw UnimplementedError();

  @override
  Future<void> setPrimaryRole(PrimaryRole role) => throw UnimplementedError();

  @override
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) => throw UnimplementedError();
}
