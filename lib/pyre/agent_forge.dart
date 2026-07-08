import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../rift/secret_vault.dart';

// ============================================================
// AGENT FORGE — HTTP client with a live device User-Agent
// ============================================================
// Every outgoing HTTP request (config gate, GCD attribution refresh,
// push image fetch) AND the in-app WebView share ONE user-agent string
// so the partner backend sees consistent session identity.
//
// The forged UA:
//   • uses the real device's Android release + brand + model + build
//     (device_info_plus) — never a hardcoded pair,
//   • embeds Chrome / WebKit version fragments unmasked from
//     `secret_vault.dart` (rotate the Chrome major per project — a
//     stale Chrome/112 in a 2026 build is a trivial cluster signal),
//   • contains ZERO Flutter / Dart / WebView / package-name substrings
//     (per `.cursor/rules/gray_user_agent.mdc`).
//
// GAME THEME CATEGORY: crash (Lava Escape — dodge-lava survival theme,
// no reels / no cards / no roulette). Per §2 of the gray_user_agent
// rule we DO NOT append `appid/...` `appname/...` at the end.
// ============================================================

class LavaAgentForge {
  LavaAgentForge();

  String _forgedAgent = 'Mozilla/5.0';
  final http.Client _inner = http.Client();

  String get agent => _forgedAgent;

  /// Reads device info + version fragments and assembles the UA. Call
  /// once during startup, BEFORE any bridge issues a request.
  Future<void> ignite() async {
    final String chrome =
        _pickWithFallback(unlockChromeFragment(), '149.0.7285.68');
    final String webkit =
        _pickWithFallback(unlockWebkitFragment(), '537.36');

    try {
      final DeviceInfoPlugin probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo info = await probe.androidInfo;
        final String buildTag = info.display.isNotEmpty ? info.display : info.id;
        _forgedAgent =
            'Mozilla/5.0 (Linux; Android ${info.version.release}; '
            '${info.brand} ${info.model} Build/$buildTag) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo info = await probe.iosInfo;
        final String osToken = info.systemVersion.replaceAll('.', '_');
        _forgedAgent =
            'Mozilla/5.0 (iPhone; CPU iPhone OS $osToken like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${info.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      _forgedAgent =
          'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/AP1A.240505.005) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit';
    }
  }

  static String _pickWithFallback(String candidate, String fallback) =>
      candidate.isNotEmpty ? candidate : fallback;

  Map<String, String> _mergedHeaders(Map<String, String>? extra) {
    final Map<String, String> merged = <String, String>{
      'User-Agent': _forgedAgent,
    };
    if (extra != null) merged.addAll(extra);
    return merged;
  }

  Future<http.Response> submit(
    Uri target,
    Object? payload, {
    Map<String, String>? headers,
    Duration? timeLimit,
  }) async {
    final Future<http.Response> call = _inner.post(
      target,
      headers: _mergedHeaders(headers),
      body: payload is Map ? jsonEncode(payload) : payload,
    );
    return timeLimit == null ? call : call.timeout(timeLimit);
  }

  Future<http.Response> fetch(
    Uri target, {
    Map<String, String>? headers,
    Duration? timeLimit,
  }) async {
    final Future<http.Response> call =
        _inner.get(target, headers: _mergedHeaders(headers));
    return timeLimit == null ? call : call.timeout(timeLimit);
  }

  void close() => _inner.close();
}

/// Process-wide singleton — one forge, one agent, both HTTP and WebView
/// pull from it so their sessions stay in sync.
final LavaAgentForge lavaAgent = LavaAgentForge();
