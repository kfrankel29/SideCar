import 'dart:async';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  final output = Directory('../../docs/design/qa/ios-final');
  await output.create(recursive: true);

  await integrationDriver(
    driver: driver,
    onScreenshot: (name, bytes, [args]) async {
      await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
