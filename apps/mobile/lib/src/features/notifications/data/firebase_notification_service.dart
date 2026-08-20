import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sidecar/src/features/notifications/domain/notification_service.dart';

class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService(this._auth, this._messaging, this._functions);

  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;
  final FirebaseFunctions _functions;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationAction> _actions =
      StreamController<NotificationAction>.broadcast();
  final StreamController<NotificationAction> _updates =
      StreamController<NotificationAction>.broadcast();
  bool _initialized = false;
  bool _listenersAttached = false;
  Future<void>? _initialization;

  static const _channel = AndroidNotificationChannel(
    'sidecar_activity',
    'Ride activity',
    description: 'Messages, booking updates, trip reminders and payouts.',
    importance: Importance.high,
  );

  @override
  Stream<NotificationAction> get actions => _actions.stream;

  @override
  Stream<NotificationAction> get updates => _updates.stream;

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final pending = _initialization;
    if (pending != null) return pending;
    final initialization = _initialize();
    _initialization = initialization;
    return initialization;
  }

  Future<void> _initialize() async {
    try {
      await _initializeOnce();
      _initialized = true;
    } finally {
      _initialization = null;
    }
  }

  Future<void> _initializeOnce() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            _actions.add(
              NotificationAction(
                decoded.map((key, value) => MapEntry('$key', '$value')),
              ),
            );
          }
        } on FormatException {
          return;
        }
      },
    );
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }

    if (!_listenersAttached) {
      _listenersAttached = true;
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) =>
            _actions.add(NotificationAction(_stringData(message.data))),
      );
      _messaging.onTokenRefresh.listen(_registerToken);
      _auth.authStateChanges().listen((user) {
        if (user != null) unawaited(refreshRegistration());
      });
    }

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      scheduleMicrotask(
        () =>
            _actions.add(NotificationAction(_stringData(initialMessage.data))),
      );
    }
    if (_auth.currentUser != null) await refreshRegistration();
  }

  @override
  Future<void> refreshRegistration() async {
    if (_auth.currentUser == null) return;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS) {
        for (var attempt = 0; attempt < 20; attempt++) {
          if (await _messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } on FirebaseException {
      return;
    } on SocketException {
      return;
    } on TimeoutException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<void> _registerToken(String token) async {
    if (_auth.currentUser == null) return;
    try {
      await _functions.httpsCallable('registerPushToken').call<void>({
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } on FirebaseFunctionsException {
      return;
    } on SocketException {
      return;
    } on TimeoutException {
      return;
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    _updates.add(NotificationAction(_stringData(message.data)));
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];
    if (title == null || body == null) return;
    try {
      await _local.show(
        message.messageId.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'sidecar_activity',
            'Ride activity',
            channelDescription:
                'Messages, booking updates, trip reminders and payouts.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } on PlatformException {
      return;
    }
  }
}

Map<String, String> _stringData(Map<String, dynamic> data) =>
    data.map((key, value) => MapEntry(key, value is String ? value : '$value'));
