import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/app_theme.dart';
import '../game/game_controller.dart';
import '../models/rune.dart';
import '../widgets/rune_button.dart';
import '../widgets/volcano_background.dart';
import 'game_over_screen.dart';
import 'pause_overlay.dart';

/// Grid order for the 8 runes. Fixed so players build spatial memory.
const List<Rune> _gridOrder = [
  Rune.circle,
  Rune.square,
  Rune.triangle,
  Rune.diamond,
  Rune.star,
  Rune.cross,
  Rune.heart,
  Rune.arrow,
];

class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with WidgetsBindingObserver {
  GameController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final controller = GameController(AppServicesScope.of(context).storage);
      controller.addListener(_onControllerChanged);
      _controller = controller;
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.startGame());
    }
  }

  void _onControllerChanged() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  void _exitToMenu() {
    Navigator.of(context).pushNamedAndRemoveUntil('/menu', (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // Guaranteed non-null: didChangeDependencies always runs before build.
    final controller = _controller!;
    final isGameOver = controller.status == GameStatus.gameOver;
    final showPause = controller.isPaused && !isGameOver;

    return Scaffold(
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (isGameOver) {
            _exitToMenu();
          } else {
            controller.pause();
          }
        },
        child: VolcanoBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _TopBar(
                      controller: controller,
                      onPause: isGameOver ? null : controller.pause,
                    ),
                    SizedBox(
                      height: 48,
                      child: Center(
                        child: _StatusLabel(controller: controller),
                      ),
                    ),
                    Expanded(
                      child: _RuneGrid(controller: controller),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                if (showPause)
                  PauseOverlay(
                    onResume: controller.resume,
                    onRestart: () {
                      controller.resume();
                      controller.restart();
                    },
                    onExit: _exitToMenu,
                  ),
                if (isGameOver)
                  GameOverOverlay(
                    score: controller.score,
                    bestScore: controller.bestScore,
                    isNewBest: controller.isNewBest,
                    onRestart: controller.restart,
                    onExit: _exitToMenu,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.onPause});

  final GameController controller;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StatChip(label: 'LEVEL', value: '${controller.level}'),
          const SizedBox(width: 14),
          _StatChip(label: 'SCORE', value: '${controller.score}'),
          const Spacer(),
          _StatChip(label: 'BEST', value: '${controller.bestScore}'),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onPause,
            icon: Icon(
              Icons.pause_circle_filled_rounded,
              color: onPause == null
                  ? AppColors.parchment.withValues(alpha: 0.3)
                  : AppColors.parchment,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.scoreLabel),
        Text(value, style: AppTextStyles.scoreValue.copyWith(fontSize: 20)),
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    String text;
    switch (controller.status) {
      case GameStatus.showingSequence:
        text = 'Watch closely...';
      case GameStatus.playerTurn:
        text = 'Your turn';
      case GameStatus.levelTransition:
        text = 'Level ${controller.level - 1} complete!';
      case GameStatus.gameOver:
      case GameStatus.idle:
        text = '';
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        text,
        key: ValueKey(text),
        style: AppTextStyles.body.copyWith(
          fontSize: 18,
          color: AppColors.lavaYellow,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RuneGrid extends StatelessWidget {
  const _RuneGrid({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final sequence = controller.sequence;
    final highlightedRune = controller.highlightedIndex >= 0 &&
            controller.highlightedIndex < sequence.length
        ? sequence[controller.highlightedIndex]
        : null;
    final inputEnabled =
        controller.status == GameStatus.playerTurn && !controller.isPaused;

    const crossAxisCount = 2;
    const rowCount = 4;
    const spacing = 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Compute the aspect ratio that makes exactly `rowCount` rows fit
          // the available height, so the last row is never pushed off
          // screen on shorter devices (e.g. with on-screen nav bars).
          final cellWidth =
              (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                  crossAxisCount;
          final cellHeight =
              (constraints.maxHeight - spacing * (rowCount - 1)) / rowCount;
          final aspectRatio = (cellWidth / cellHeight).clamp(0.55, 1.6);

          return GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
            physics: const NeverScrollableScrollPhysics(),
            children: _gridOrder.map((rune) {
              final isHighlighted = highlightedRune == rune &&
                  controller.status == GameStatus.showingSequence;
              final isFeedback = controller.feedbackRune == rune &&
                  controller.status != GameStatus.showingSequence;
              return RuneButton(
                rune: rune,
                highlighted: isHighlighted || isFeedback,
                errorFlash: isFeedback && controller.feedbackIsError,
                enabled: inputEnabled,
                onTap: () => controller.onRuneTap(rune),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
