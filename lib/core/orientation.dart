import 'package:flutter/services.dart';

/// Locks the app to portrait orientation. The loading screen is the only
/// screen allowed to render in landscape (e.g. tablets / freeform windows);
/// every other screen calls this once before taking over.
Future<void> lockPortraitOrientation() {
  return SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}

/// Releases the orientation lock so the loading screen can freely follow
/// the device's current orientation.
Future<void> unlockOrientationForLoading() {
  return SystemChrome.setPreferredOrientations(DeviceOrientation.values);
}
