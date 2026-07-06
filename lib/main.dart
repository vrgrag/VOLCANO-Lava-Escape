import 'package:flutter/material.dart';

import 'core/app_services.dart';
import 'core/app_theme.dart';
import 'core/orientation.dart';
import 'screens/gameplay_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/no_internet_screen.dart';
import 'screens/webview_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The loading screen is allowed to render in either orientation; the
  // rest of the game is strictly portrait. We start unlocked and lock to
  // portrait once the loading screen hands off to the rest of the app.
  await unlockOrientationForLoading();
  final storage = await StorageService.create();
  final services = AppServices(storage: storage);
  runApp(LavaEscapeApp(services: services));
}

class LavaEscapeApp extends StatelessWidget {
  const LavaEscapeApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: services,
      child: MaterialApp(
        title: 'Lava Escape',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const LoadingScreen());
            case '/menu':
              return MaterialPageRoute(
                builder: (_) => const MainMenuScreen(),
                settings: settings,
              );
            case '/game':
              return MaterialPageRoute(builder: (_) => const GameplayScreen());
            case '/webview':
              final args = settings.arguments as WebViewArgs;
              return MaterialPageRoute(
                builder: (_) => WebViewScreen(args: args),
              );
            case '/no-internet':
              final args = settings.arguments as WebViewArgs;
              return MaterialPageRoute(
                builder: (_) => NoInternetScreen(args: args),
              );
            default:
              return MaterialPageRoute(builder: (_) => const LoadingScreen());
          }
        },
      ),
    );
  }
}
