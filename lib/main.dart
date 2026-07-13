import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_services.dart';
import 'core/orientation.dart';
import 'pyre/agent_forge.dart';
import 'pyre/attribution_scout.dart';
import 'pyre/beacon_hub.dart';
import 'pyre/caverns_vault.dart';
import 'pyre/signal_probe.dart';
import 'pyre/verdict_channel.dart';
import 'quake/escape_app.dart';
import 'services/storage_service.dart';
import 'wire/route_mode.dart';

// ============================================================
// main.dart — Lava Escape bootstrap
// ============================================================
// Wiring order (do NOT reorder without re-reading the guide):
//   1. WidgetsFlutterBinding.
//   2. Firebase + App Check — wrapped in try/catch. Missing
//      google-services.json is NOT fatal; the gray flow falls back to
//      the offline game.
//   3. Orientation whitelist — all four orientations unlocked. The
//      boot router re-locks to portrait when it routes into the game.
//   4. Status bar transparent + light icons — loading art is edge-to-edge.
//   5. `lavaAgent.ignite()` — forges the User-Agent BEFORE any bridge
//      makes its first HTTP call.
//   6. `CavernsVault.mount()` — reads SharedPreferences into memory so
//      the first frame of BootRouter can decide the route synchronously.
//   7. Bridges are constructed here but their `.wire()` / `.lightUp()`
//      calls run inside BootRouter, after the UI is up.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check are optional until credentials land — failures
  // here must never block startup.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  // Loading + WebView need every orientation. The game re-locks to
  // portrait inside BootRouter._routeNative.
  await unlockOrientationForLoading();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await lavaAgent.ignite();

  final CavernsVault vault = CavernsVault();
  await vault.mount();

  // White-part storage is separate from the vault; keep it wired for the
  // native game path (BEST score, sound flag). It never talks to the
  // gray subsystem — the two paths only meet at BootRouter.
  final StorageService whiteStore = await StorageService.create();
  final AppServices whiteServices = AppServices(storage: whiteStore);

  final SignalProbe signal = SignalProbe();
  final AttributionScout scout = AttributionScout();
  final VerdictChannel verdict = VerdictChannel(vault);
  final BeaconHub beacon = BeaconHub(vault);

  // Persistent token-rotation handler — outlives BootRouter so a token
  // that only arrives after the shell has already handed off to the
  // WebView still triggers a re-POST of the config request. Without
  // this, notifications silently fail after an offline→retry cycle
  // because the backend never receives the token.
  beacon.onFreshToken = (String token) async {
    if (vault.currentMode() != RouteMode.escape) return;
    try {
      final Map<String, dynamic> body = await scout.composeGateBody(
        locale: Platform.localeName.replaceAll('-', '_'),
        pushToken: token,
      );
      await verdict.query(body);
    } catch (_) {}
  };

  runApp(
    AppServicesScope(
      services: whiteServices,
      child: EscapeApp(
        vault: vault,
        signal: signal,
        scout: scout,
        verdict: verdict,
        beacon: beacon,
      ),
    ),
  );
}
