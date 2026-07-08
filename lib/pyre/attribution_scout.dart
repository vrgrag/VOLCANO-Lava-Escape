import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../rift/identity.dart';
import '../rift/secret_vault.dart';
import 'agent_forge.dart';

// ============================================================
// ATTRIBUTION SCOUT — AppsFlyer + deep-link harvesting
// ============================================================
// Collects three sources of attribution data:
//   • install conversion payload (`onInstallConversionData`),
//   • deep-link click event (`onDeepLinking`),
//   • app-open re-attribution (`onAppOpenAttribution`).
//
// Any callback populates a `_snapshot` map; the router waits on two
// `Future`s that flip to `true` when their respective source resolves,
// timing out gracefully so a missing callback never stalls startup.
//
// Organic-false-positive guard: AppsFlyer occasionally reports
// `af_status: "Organic"` on the first callback for a real paid install.
// When that happens the scout waits a few seconds and re-queries GCD
// to obtain the true attribution.
// ============================================================

class AttributionScout {
  AppsflyerSdk? _sdk;

  Map<String, dynamic> _installShot = <String, dynamic>{};
  Map<String, dynamic>? _deepLinkShot;
  Map<String, dynamic>? _reopenShot;

  final Completer<void> _installDone = Completer<void>();
  final Completer<void> _deepDone = Completer<void>();

  bool _lit = false;

  /// Ignites the SDK. Safe to call once; subsequent calls no-op.
  Future<void> lightUp() async {
    if (_lit) return;
    _lit = true;

    final String key = EscapeIdentity.attributionKey;
    if (key.isEmpty) {
      // No dev-key packed yet → don't stall the boot pipeline waiting
      // for attribution that will never arrive. Complete both channels
      // immediately with empty data.
      _finishInstall();
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: key,
      appId: EscapeIdentity.appleStoreId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> shot = _flatten(raw);
      final String? status = shot['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: EscapeIdentity.organicRepeatDelaySeconds),
        );
        final Map<String, dynamic>? refined = await _refineViaGcd();
        _installShot = refined ?? shot;
      } else {
        _installShot = shot;
      }
      _finishInstall();
    });

    sdk.onDeepLinking((DeepLinkResult res) {
      final Map<String, dynamic>? click = res.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkShot = Map<String, dynamic>.from(click);
      }
      _finishDeepLink();
    });

    sdk.onAppOpenAttribution((dynamic raw) {
      _reopenShot = _flatten(raw);
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall();
      _finishDeepLink();
    }
  }

  Future<void> waitForInstall({int seconds = 30}) => _installDone.future
      .timeout(Duration(seconds: seconds), onTimeout: () {});

  Future<void> waitForDeepLink() => _deepDone.future
      .timeout(const Duration(seconds: 5), onTimeout: () {});

  Future<String> apparatusUid() async {
    if (_sdk == null) return '';
    try {
      final String? id = await _sdk!.getAppsFlyerUID();
      return id ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Composes the merged gate body per §"Config Request Contract".
  ///
  /// Rules enforced here:
  ///   • Attribution payload keys pass through verbatim (never rename,
  ///     never drop, never mutate values).
  ///   • Deep-link + reopen data merge with `putIfAbsent` so they never
  ///     overwrite conversion data.
  ///   • Device-side fields are written LAST so they always overwrite.
  ///   • `push_token` / `firebase_project_id` are omitted (key removed)
  ///     when the token or project is not available — never sent as
  ///     `null` or empty strings.
  Future<Map<String, dynamic>> composeGateBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    body.addAll(_installShot);
    _deepLinkShot?.forEach(
      (String k, dynamic v) => body.putIfAbsent(k, () => v),
    );
    _reopenShot?.forEach(
      (String k, dynamic v) => body.putIfAbsent(k, () => v),
    );

    body['af_id'] = await apparatusUid();
    body['bundle_id'] = EscapeIdentity.bundle;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = EscapeIdentity.marketPlace;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
      final String project = EscapeIdentity.messagingProject;
      if (project.isNotEmpty) {
        body['firebase_project_id'] = project;
      }
    }

    if (kDebugMode) {
      debugPrint('[AttributionScout] gate body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _refineViaGcd() async {
    try {
      final String deviceId = await apparatusUid();
      if (deviceId.isEmpty) return null;
      final String appId = Platform.isIOS
          ? EscapeIdentity.appleStoreId
          : EscapeIdentity.bundle;
      final String url = buildGcdUrl(appId, deviceId);
      if (url.isEmpty) return null;

      final response = await lavaAgent.fetch(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${EscapeIdentity.attributionKey}',
        },
        timeLimit: const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall() {
    if (!_installDone.isCompleted) _installDone.complete();
  }

  void _finishDeepLink() {
    if (!_deepDone.isCompleted) _deepDone.complete();
  }

  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map(
        (dynamic k, dynamic v) =>
            MapEntry<String, dynamic>(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }
}
