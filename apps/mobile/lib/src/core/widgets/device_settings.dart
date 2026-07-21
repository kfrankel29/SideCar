import 'package:flutter/services.dart';

abstract final class DeviceSettings {
  static const _channel = MethodChannel('com.kaileefrankel.sidecar/settings');

  static Future<void> openAppSettings() {
    return _channel.invokeMethod<void>('openAppSettings');
  }
}
