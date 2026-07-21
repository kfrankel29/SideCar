import 'dart:async';

import 'package:flutter/services.dart';

abstract final class AppHaptics {
  static void tap() {
    unawaited(HapticFeedback.selectionClick());
  }

  static VoidCallback? wrap(VoidCallback? callback) {
    if (callback == null) return null;
    return () {
      tap();
      callback();
    };
  }
}
