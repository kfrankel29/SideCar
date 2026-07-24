import 'package:flutter/services.dart';

class InstallState {
  const InstallState._();

  static const _channel = MethodChannel('com.kaileefrankel.sidecar/settings');

  static Future<bool> consumeFreshInstall() async {
    try {
      return await _channel.invokeMethod<bool>('consumeFreshInstall') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> clearRestoredSessionIfNeeded(
    Future<void> Function() signOut,
  ) async {
    if (await consumeFreshInstall()) {
      await signOut();
    }
  }
}
