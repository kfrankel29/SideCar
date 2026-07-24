import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/core/platform/install_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.kaileefrankel.sidecar/settings');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the native fresh-install result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'consumeFreshInstall');
          return true;
        });

    expect(await InstallState.consumeFreshInstall(), isTrue);
  });

  test('fails closed when the platform channel is unavailable', () async {
    expect(await InstallState.consumeFreshInstall(), isFalse);
  });

  test('clears a Keychain-restored session after reinstall', () async {
    var signedOut = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);

    await InstallState.clearRestoredSessionIfNeeded(() async {
      signedOut = true;
    });

    expect(signedOut, isTrue);
  });

  test('keeps a valid session during a normal relaunch', () async {
    var signedOut = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);

    await InstallState.clearRestoredSessionIfNeeded(() async {
      signedOut = true;
    });

    expect(signedOut, isFalse);
  });
}
