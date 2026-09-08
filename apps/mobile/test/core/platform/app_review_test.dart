import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/core/platform/app_review.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.kaileefrankel.sidecar/settings');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('requests the native app review flow', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return true;
        });

    expect(await AppReview.request(), isTrue);
    expect(received?.method, 'requestAppReview');
  });

  test('fails safely when the native review flow is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });

    expect(await AppReview.request(), isFalse);
  });
}
