import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/notifications/domain/notification_service.dart';
import 'package:sidecar/src/features/navigation/domain/tab_activation.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class SideCarApp extends ConsumerStatefulWidget {
  const SideCarApp({super.key});

  @override
  ConsumerState<SideCarApp> createState() => _SideCarAppState();
}

class _SideCarAppState extends ConsumerState<SideCarApp>
    with WidgetsBindingObserver {
  bool _wasBackgrounded = false;
  bool _isValidatingSession = false;
  int _notificationInitializationAttempts = 0;
  StreamSubscription<NotificationAction>? _notificationSubscription;
  StreamSubscription<NotificationAction>? _notificationUpdateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleMicrotask(_initializeNotifications);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    _notificationUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    final service = ref.read(notificationServiceProvider);
    _notificationSubscription ??= service.actions.listen(_openNotification);
    _notificationUpdateSubscription ??= service.updates.listen(
      (_) => _refreshNotificationState(),
    );
    try {
      await service.initialize();
    } on Object {
      if (!mounted || _notificationInitializationAttempts >= 2) return;
      _notificationInitializationAttempts += 1;
      await Future<void>.delayed(
        Duration(seconds: _notificationInitializationAttempts),
      );
      if (mounted) await _initializeNotifications();
    }
  }

  void _openNotification(NotificationAction action) {
    if (!mounted) return;
    final router = ref.read(appRouterProvider);
    router.go(notificationDestination(action.data));
  }

  void _refreshNotificationState() {
    if (!mounted) return;
    ref.invalidate(driverPendingRequestCountProvider);
    ref.read(mainTabActivationProvider.notifier).activate(0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _wasBackgrounded = true;
      case AppLifecycleState.resumed:
        if (_wasBackgrounded) {
          _wasBackgrounded = false;
          _refreshNotificationState();
          unawaited(_validateRestoredSession());
        }
    }
  }

  Future<void> _validateRestoredSession() async {
    if (_isValidatingSession ||
        ref.read(authRepositoryProvider).currentUser == null) {
      return;
    }

    _isValidatingSession = true;
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .validateCurrentSession();
      if (user == null) {
        _resetToWelcome();
        return;
      }
      final profile = await ref
          .read(profileRepositoryProvider)
          .loadCurrentProfile();
      if (profile == null) {
        await ref.read(authRepositoryProvider).signOut();
        _resetToWelcome();
      }
    } on Object {
      return;
    } finally {
      _isValidatingSession = false;
    }
  }

  void _resetToWelcome() {
    if (mounted) ref.read(appRouterProvider).go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SideCar',
      scaffoldMessengerKey: sideCarScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

String notificationDestination(Map<String, String> data) {
  final conversationId = data['conversationId']?.trim();
  if (conversationId != null && conversationId.isNotEmpty) {
    return '/messages/${Uri.encodeComponent(conversationId)}';
  }

  final route = data['route']?.trim();
  final rideId = data['rideId']?.trim();
  if ((route == 'live_trip' || route == 'rating') &&
      rideId != null &&
      rideId.isNotEmpty) {
    return '/rides/${Uri.encodeComponent(rideId)}';
  }

  if (route == 'messages') return AppRoutes.messages;
  return AppRoutes.myRides;
}
