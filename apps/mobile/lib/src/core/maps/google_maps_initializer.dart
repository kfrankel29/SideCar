import 'dart:io';

import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Selects the current Google Maps renderer before any map view is created.
Future<void> initializeGoogleMapsPlatform() async {
  if (!Platform.isAndroid) return;

  final implementation = GoogleMapsFlutterPlatform.instance;
  if (implementation is! GoogleMapsFlutterAndroid) return;

  await implementation.initializeWithRenderer(AndroidMapRenderer.latest);
  await implementation.warmup();
}
