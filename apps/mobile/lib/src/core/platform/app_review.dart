import 'package:flutter/services.dart';

class AppReview {
  AppReview._();

  static const _channel = MethodChannel('com.kaileefrankel.sidecar/settings');

  static Future<bool> request() async {
    try {
      return await _channel.invokeMethod<bool>('requestAppReview') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
