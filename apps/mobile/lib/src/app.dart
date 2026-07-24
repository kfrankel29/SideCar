import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      try {
        await ref.read(authRepositoryProvider).signOut();
      } on Object {
        // The server validation failed, so the app still returns to sign-in.
      }
      _resetToWelcome();
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
