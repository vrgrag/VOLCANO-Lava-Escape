import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/rune.dart';

/// A single tappable rune tile. Since the art already bakes in the glowing
/// lava carving, "highlighted" is conveyed with a scale pop + warm glow
/// halo + brightness boost rather than swapping images.
class RuneButton extends StatelessWidget {
  const RuneButton({
    super.key,
    required this.rune,
    required this.highlighted,
    required this.errorFlash,
    required this.enabled,
    required this.onTap,
  });

  final Rune rune;
  final bool highlighted;
  final bool errorFlash;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color glow =
        errorFlash ? AppColors.danger : AppColors.lavaYellow;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: highlighted ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.9),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: glow.withValues(alpha: 0.5),
                      blurRadius: 55,
                      spreadRadius: 8,
                    ),
                  ]
                : const [],
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlighted
                  ? glow.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.18),
            ),
            child: Opacity(
              opacity: enabled ? 1.0 : 0.55,
              child: ColorFiltered(
                colorFilter: highlighted
                    ? ColorFilter.mode(
                        glow.withValues(alpha: 0.28),
                        BlendMode.plus,
                      )
                    : const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.dst,
                      ),
                child: Image.asset(rune.assetPath, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
