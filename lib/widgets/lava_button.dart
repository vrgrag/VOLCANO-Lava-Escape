import 'package:flutter/material.dart';

import '../core/app_theme.dart';

enum LavaButtonStyle { primary, secondary, danger }

/// A stone-and-lava styled button matching the rune art direction, used
/// throughout menus since no dedicated button asset was supplied.
class LavaButton extends StatefulWidget {
  const LavaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = LavaButtonStyle.primary,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final LavaButtonStyle style;
  final IconData? icon;
  final bool expand;

  @override
  State<LavaButton> createState() => _LavaButtonState();
}

class _LavaButtonState extends State<LavaButton> {
  bool _pressed = false;

  List<Color> get _gradientColors {
    switch (widget.style) {
      case LavaButtonStyle.primary:
        return const [AppColors.lavaOrange, AppColors.lavaRed];
      case LavaButtonStyle.secondary:
        return const [AppColors.stoneLight, AppColors.stone];
      case LavaButtonStyle.danger:
        return const [AppColors.danger, AppColors.obsidianDark];
    }
  }

  Color get _glowColor {
    switch (widget.style) {
      case LavaButtonStyle.primary:
        return AppColors.lavaOrange;
      case LavaButtonStyle.secondary:
        return Colors.black;
      case LavaButtonStyle.danger:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final content = AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: disabled
                ? const [AppColors.stone, AppColors.obsidianDark]
                : _gradientColors,
          ),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.55),
            width: 2,
          ),
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: _glowColor.withValues(alpha: 0.55),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                  const BoxShadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: AppColors.parchment, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: AppTextStyles.button.copyWith(
                color: disabled
                    ? AppColors.parchment.withValues(alpha: 0.4)
                    : AppColors.parchment,
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: widget.expand ? content : content,
    );
  }
}
