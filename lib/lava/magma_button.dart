import 'package:flutter/material.dart';

// ============================================================
// MAGMA BUTTON — hex-shell button used by every gray-shell screen
// ============================================================
// Distinct visual identity so nothing in the gray flow looks like the
// generic pill / gold-gradient buttons that circulate in reference
// templates. The button paints:
//
//   • A dark obsidian bevel border (2 dp)
//   • A radial glow behind the label (lava red → orange)
//   • The label with an inner brightness pulse on press
//   • Baseline-hardened text (height 1.0) to prevent visual tilt
//
// Two variants share the same skeleton:
//   MagmaButton   — solid, primary action ("Reconnect", "Enable")
//   MagmaGhost    — outlined variant, secondary action ("Skip")
// Both are gradient buttons (never subdued text) so they read on any
// backdrop — see pitfalls §12.
// ============================================================

enum MagmaTone { primary, secondary }

class MagmaButton extends StatefulWidget {
  const MagmaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.height = 56,
    this.tone = MagmaTone.primary,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final double height;
  final MagmaTone tone;

  @override
  State<MagmaButton> createState() => _MagmaButtonState();
}

class _MagmaButtonState extends State<MagmaButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static const Color _obsidian = Color(0xFF120A08);
  static const Color _lavaRed = Color(0xFFE23B1F);
  static const Color _lavaOrange = Color(0xFFFF8B2C);
  static const Color _lavaYellow = Color(0xFFFFC96B);
  static const Color _parchment = Color(0xFFFDF1D6);

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = widget.tone == MagmaTone.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (BuildContext context, Widget? child) {
            final double glow = 0.55 + (_pulse.value * 0.35);
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isPrimary
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[_lavaYellow, _lavaOrange, _lavaRed],
                        stops: <double>[0.0, 0.55, 1.0],
                      )
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          _obsidian.withValues(alpha: 0.75),
                          _obsidian.withValues(alpha: 0.55),
                        ],
                      ),
                border: Border.all(
                  color: isPrimary
                      ? _obsidian.withValues(alpha: 0.85)
                      : _lavaOrange.withValues(alpha: 0.75),
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (isPrimary ? _lavaOrange : _lavaRed)
                        .withValues(alpha: glow * 0.55),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                  const BoxShadow(
                    color: Color(0x55000000),
                    offset: Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isPrimary ? _obsidian : _parchment,
                  fontSize: widget.height <= 46 ? 16 : 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  height: 1.0,
                  shadows: <Shadow>[
                    Shadow(
                      color: isPrimary
                          ? _parchment.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
