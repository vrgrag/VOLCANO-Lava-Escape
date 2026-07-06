import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/assets.dart';
import '../core/orientation.dart';
import '../widgets/lava_progress_bar.dart';
import '../widgets/loading_dots_text.dart';

/// First screen shown. Genuinely pre-caches every game asset and only
/// reports the fraction of that real work that has completed — the
/// progress bar can never reach 100% before the app has actually finished
/// loading. This is the only screen allowed to render in either
/// orientation; every other screen is locked to portrait.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                isLandscape
                    ? AppAssets.loadingHorizontal
                    : AppAssets.loadingVertical,
                fit: BoxFit.cover,
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 80 : 36,
                    vertical: 36,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const LoadingDotsText(style: AppTextStyles.heading),
                      const SizedBox(height: 18),
                      LavaProgressBar(progress: _progress),
                      const SizedBox(height: 8),
                      Text(
                        '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    final stopwatch = Stopwatch()..start();
    final images = AppAssets.precacheImages;
    final total = images.length;
    var done = 0;

    for (final path in images) {
      if (!mounted) return;
      await precacheImage(AssetImage(path), context);
      done++;
      if (!mounted) return;
      setState(() => _progress = done / total);
    }

    // Purely cosmetic minimum display time — it never lets the bar show
    // completion before the loop above has genuinely finished; it only
    // holds the already-100% bar on screen a little longer.
    const minDisplay = Duration(milliseconds: 1100);
    final elapsed = stopwatch.elapsed;
    if (elapsed < minDisplay) {
      await Future.delayed(minDisplay - elapsed);
    }

    if (!mounted) return;
    await lockPortraitOrientation();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/menu');
  }
}
