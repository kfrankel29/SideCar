import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/app.dart';
import 'package:sidecar/src/routing/app_router.dart';

void main() {
  group('notificationDestination', () {
    test('opens a conversation when a conversation id is present', () {
      expect(
        notificationDestination({
          'route': 'messages',
          'conversationId': 'conversation/with spaces',
        }),
        '/messages/conversation%2Fwith%20spaces',
      );
    });

    test('opens the ride for live trip activity', () {
      expect(
        notificationDestination({'route': 'live_trip', 'rideId': 'ride/123'}),
        '/rides/ride%2F123',
      );
    });

    test('opens the completed ride for rating activity', () {
      expect(
        notificationDestination({'route': 'rating', 'rideId': 'ride/123'}),
        '/rides/ride%2F123',
      );
    });

    test('opens the messages tab without a conversation id', () {
      expect(
        notificationDestination({'route': 'messages'}),
        AppRoutes.messages,
      );
    });

    test('falls back to my rides without a specific destination', () {
      expect(notificationDestination({'route': 'rating'}), AppRoutes.myRides);
      expect(notificationDestination(const {}), AppRoutes.myRides);
    });
  });
}
