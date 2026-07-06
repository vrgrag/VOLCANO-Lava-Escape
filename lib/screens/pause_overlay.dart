import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/lava_button.dart';

/// Full-screen pause overlay shown on top of the Gameplay screen.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: AppColors.stone.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.lavaOrange.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black, blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pause_circle_filled_rounded,
                    color: AppColors.lavaYellow, size: 48),
                const SizedBox(height: 10),
                const Text('Paused', style: AppTextStyles.heading),
                const SizedBox(height: 24),
                LavaButton(
                  label: 'Resume',
                  icon: Icons.play_arrow_rounded,
                  onPressed: onResume,
                ),
                const SizedBox(height: 12),
                LavaButton(
                  label: 'Restart',
                  icon: Icons.refresh_rounded,
                  style: LavaButtonStyle.secondary,
                  onPressed: onRestart,
                ),
                const SizedBox(height: 12),
                LavaButton(
                  label: 'Main Menu',
                  icon: Icons.home_rounded,
                  style: LavaButtonStyle.secondary,
                  onPressed: onExit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
