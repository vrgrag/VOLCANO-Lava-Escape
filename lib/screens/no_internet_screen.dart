import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/app_theme.dart';
import '../widgets/lava_button.dart';
import '../widgets/volcano_background.dart';
import 'webview_screen.dart';

/// Shown when the player tries to open Privacy Policy / Support without a
/// network connection. The core game never needs this screen — only the
/// two optional remote content pages do.
class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key, required this.args});

  final WebViewArgs args;

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    final services = AppServicesScope.of(context);
    final online = await services.connectivity.hasConnection();
    if (!mounted) return;
    setState(() => _checking = false);
    if (online) {
      Navigator.of(context).pushReplacementNamed('/webview', arguments: widget.args);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still no connection. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VolcanoBackground(
        overlayOpacity: 0.55,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: AppColors.lavaOrange, size: 72),
                const SizedBox(height: 20),
                const Text(
                  'No Internet Connection',
                  style: AppTextStyles.heading,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Connect to the internet to view "${widget.args.title}".\nThe game itself works fully offline.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                LavaButton(
                  label: _checking ? 'Checking...' : 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: _checking ? null : _retry,
                ),
                const SizedBox(height: 14),
                LavaButton(
                  label: 'Back',
                  style: LavaButtonStyle.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
