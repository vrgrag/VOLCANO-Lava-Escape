import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// A left-to-right filling progress bar styled as a molten crack in stone.
///
/// [progress] must reflect *real* completed work (0.0-1.0) — the bar only
/// ever animates smoothly towards the latest known-true value, it never
/// advances further than what has actually finished loading.
class LavaProgressBar extends StatelessWidget {
  const LavaProgressBar({super.key, required this.progress, this.height = 18});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        color: AppColors.obsidianDark,
        border: Border.all(color: Colors.black.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                final width = maxWidth * value;
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: height - 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height),
                        color: Colors.black.withValues(alpha: 0.25),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: width,
                      height: height - 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height),
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.lavaRed,
                            AppColors.lavaOrange,
                            AppColors.lavaYellow,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lavaOrange.withValues(alpha: 0.75),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
