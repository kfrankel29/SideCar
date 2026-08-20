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
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => const UnavailableNotificationService(),
);
