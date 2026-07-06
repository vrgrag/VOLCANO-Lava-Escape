import 'package:flutter/material.dart';

import '../core/assets.dart';

/// Full-bleed volcanic backdrop used behind every in-game screen, with a
/// subtle dark gradient overlay so foreground UI stays readable.
class VolcanoBackground extends StatelessWidget {
  const VolcanoBackground({super.key, this.child, this.overlayOpacity = 0.35});

  final Widget? child;
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(AppAssets.backgroundDark, fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: overlayOpacity + 0.15),
                Colors.black.withValues(alpha: overlayOpacity),
                Colors.black.withValues(alpha: overlayOpacity + 0.25),
              ],
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}
