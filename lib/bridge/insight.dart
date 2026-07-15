import 'package:clarity_flutter/clarity_flutter.dart';

import '../env/insight_env.dart';

// ============================================================
// INSIGHT — crash-safe facade over Microsoft Clarity
// ============================================================
// Session replay covers the native Flutter surface (loading, invite,
// game, WebView container). The DOM inside the WebView is NOT
// recorded, so the offer funnel (page changes, deposit taps,
// sign-up / login) is only visible via the custom events emitted by
// the JS probe injected in `EscapeView`.
//
// Every call here is guarded so a Clarity SDK failure can never
// bubble into the gray flow and crash startup.
// ============================================================

class Insight {
  const Insight._();

  static ClarityConfig get config => ClarityConfig(
        projectId: kClarityProjectId,
        // Verbose while wiring / debugging a fresh project so the SDK
        // prints every HTTP call to logcat. Switch back to LogLevel.None
        // for release once the dashboard confirms sessions are arriving.
        logLevel: LogLevel.Verbose,
      );

  /// Group the session by AppsFlyer id + attach attribution tags.
  /// No-op on empty id so a missing af_id never wipes a good user id.
  static void identify(String? aid, {Map<String, String> tags = const {}}) {
    if (aid != null && aid.isNotEmpty) {
      _guard(() => Clarity.setCustomUserId(_clip(aid, 255)));
      tag('aid', aid);
    }
    tags.forEach(tag);
  }

  /// Native screen: sets the label AND emits a stable per-screen event.
  static void screen(String name) {
    screenName(name);
    event('screen_$name');
  }

  /// Sets the current screen label + mirrors it into the persistent
  /// `last_screen` tag (Clarity keeps the LAST tag value per session, so
  /// filtering by last_screen instantly shows the drop-off screen).
  static void screenName(String name) => _guard(() {
        Clarity.setCurrentScreenName(_clip(name, 255));
        Clarity.setCustomTag('last_screen', _clip(name, 255));
      });

  static void event(String name) =>
      _guard(() => Clarity.sendCustomEvent(_clip(name, 254)));

  static void tag(String key, String value) {
    if (value.isEmpty) return;
    _guard(() => Clarity.setCustomTag(key, _clip(value, 255)));
  }

  static String _clip(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);

  static void _guard(void Function() body) {
    try {
      body();
    } catch (_) {}
  }
}
