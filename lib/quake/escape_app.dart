import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../pyre/attribution_scout.dart';
import '../pyre/beacon_hub.dart';
import '../pyre/caverns_vault.dart';
import '../pyre/signal_probe.dart';
import '../pyre/verdict_channel.dart';
import '../rift/identity.dart';
import '../screens/gameplay_screen.dart';
import '../screens/main_menu_screen.dart';
import '../screens/no_internet_screen.dart';
import '../screens/webview_screen.dart';
import 'boot_router.dart';

/// Root widget. Owns the long-lived shell services and hands them to the
/// router. The MaterialApp title pulls from [EscapeIdentity] so it stays
/// in perfect sync with the Play Console listing.
class EscapeApp extends StatelessWidget {
  const EscapeApp({
    super.key,
    required this.vault,
    required this.signal,
    required this.scout,
    required this.verdict,
    required this.beacon,
  });

  final CavernsVault vault;
  final SignalProbe signal;
  final AttributionScout scout;
  final VerdictChannel verdict;
  final BeaconHub beacon;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: EscapeIdentity.presentedName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: BootRouter(
        vault: vault,
        signal: signal,
        scout: scout,
        verdict: verdict,
        beacon: beacon,
      ),
      // Named routes only reachable from inside the native game path.
      // BootRouter uses `pushReplacement(MaterialPageRoute(...))`
      // directly and does NOT rely on named routes.
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/menu':
            return MaterialPageRoute<void>(
              builder: (_) => const MainMenuScreen(),
              settings: settings,
            );
          case '/game':
            return MaterialPageRoute<void>(
              builder: (_) => const GameplayScreen(),
              settings: settings,
            );
          case '/webview':
            final WebViewArgs args = settings.arguments as WebViewArgs;
            return MaterialPageRoute<void>(
              builder: (_) => WebViewScreen(args: args),
              settings: settings,
            );
          case '/no-internet':
            final WebViewArgs args = settings.arguments as WebViewArgs;
            return MaterialPageRoute<void>(
              builder: (_) => NoInternetScreen(args: args),
              settings: settings,
            );
          default:
            return null;
        }
      },
    );
  }
}
