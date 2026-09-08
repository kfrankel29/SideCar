import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationAction {
  const NotificationAction(this.data);

  final Map<String, String> data;
}

abstract interface class NotificationService {
  Stream<NotificationAction> get actions;
  Stream<NotificationAction> get updates;
  Future<void> initialize();
  Future<void> refreshRegistration();
  Future<int> unreadRideUpdateCount();
  Future<void> markRideUpdatesRead();
}

class UnavailableNotificationService implements NotificationService {
  const UnavailableNotificationService();

  @override
  Stream<NotificationAction> get actions => const Stream.empty();

  @override
  Stream<NotificationAction> get updates => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshRegistration() async {}

  @override
  Future<int> unreadRideUpdateCount() async => 0;

  @override
  Future<void> markRideUpdatesRead() async {}
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => const UnavailableNotificationService(),
);

final rideNotificationAttentionProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  try {
    return await ref.read(notificationServiceProvider).unreadRideUpdateCount();
  } on Object {
    return 0;
  }
});
