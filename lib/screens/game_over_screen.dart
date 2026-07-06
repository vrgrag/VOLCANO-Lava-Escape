import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../widgets/lava_button.dart';

/// Full-screen Game Over overlay shown on top of the Gameplay screen once
/// the player taps a wrong rune. Displays the run's score and the
/// all-time best score (persisted locally).
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.isNewBest,
    required this.onRestart,
    required this.onExit,
  });

  final int score;
  final int bestScore;
  final bool isNewBest;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.stone.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: AppColors.danger, size: 52),
                const SizedBox(height: 8),
                const Text('GAME OVER', style: AppTextStyles.title),
                if (isNewBest) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'NEW BEST SCORE!',
                    style: TextStyle(
                      color: AppColors.lavaYellow,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ScoreColumn(label: 'SCORE', value: score),
                    Container(
                      width: 1,
                      height: 42,
                      color: AppColors.parchment.withValues(alpha: 0.25),
                    ),
                    _ScoreColumn(label: 'BEST', value: bestScore),
                  ],
                ),
                const SizedBox(height: 28),
                LavaButton(
                  label: 'Restart',
                  icon: Icons.refresh_rounded,
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

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.scoreLabel),
        const SizedBox(height: 4),
        Text('$value', style: AppTextStyles.scoreValue),
      ],
    );
  }
}
