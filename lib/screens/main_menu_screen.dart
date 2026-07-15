import 'package:flutter/material.dart';

import '../bridge/insight.dart';
import '../core/app_services.dart';
import '../core/app_theme.dart';
import '../core/assets.dart';
import '../widgets/lava_button.dart';
import '../widgets/volcano_background.dart';
import 'webview_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  static const String _privacyUrl = 'https://lavaesscape.com/privacy-policy.html';
  static const String _supportUrl = 'https://lavaesscape.com/support.html';

  @override
  void initState() {
    super.initState();
    Insight.screen('menu');
  }

  Future<void> _openRemote(String title, String url) async {
    final services = AppServicesScope.of(context);
    final online = await services.connectivity.hasConnection();
    final args = WebViewArgs(title: title, url: url);
    if (!mounted) return;
    if (online) {
      Navigator.of(context).pushNamed('/webview', arguments: args);
    } else {
      Navigator.of(context).pushNamed('/no-internet', arguments: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    return Scaffold(
      body: VolcanoBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Hero(
                  tag: 'logo',
                  child: Image.asset(
                    AppAssets.logo,
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                _BestScoreChip(bestScore: services.storage.bestScore),
                const Spacer(flex: 3),
                LavaButton(
                  label: 'Play',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => Navigator.of(context).pushNamed('/game'),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FooterLink(
                      label: 'Privacy Policy',
                      onTap: () => _openRemote('Privacy Policy', _privacyUrl),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 14,
                      color: AppColors.parchment.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 12),
                    _FooterLink(
                      label: 'Support',
                      onTap: () => _openRemote('Support', _supportUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BestScoreChip extends StatelessWidget {
  const _BestScoreChip({required this.bestScore});

  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.obsidianDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.lavaOrange.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.lavaYellow, size: 20),
          const SizedBox(width: 8),
          Text('BEST: $bestScore', style: AppTextStyles.scoreLabel.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          color: AppColors.parchment.withValues(alpha: 0.75),
          decoration: TextDecoration.underline,
          decorationColor: AppColors.parchment.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
