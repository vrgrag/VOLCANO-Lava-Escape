import 'package:flutter/material.dart';

/// Central palette & text styles for the volcanic/lava rune theme.
class AppColors {
  AppColors._();

  static const Color obsidian = Color(0xFF0D0806);
  static const Color obsidianDark = Color(0xFF060302);
  static const Color stone = Color(0xFF2B2320);
  static const Color stoneLight = Color(0xFF4A3B34);
  static const Color lavaOrange = Color(0xFFFF7A1A);
  static const Color lavaYellow = Color(0xFFFFC64B);
  static const Color lavaRed = Color(0xFFE1391B);
  static const Color parchment = Color(0xFFF3E3C9);
  static const Color danger = Color(0xFFD62828);
}

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Roboto';

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    color: AppColors.parchment,
    letterSpacing: 1.5,
    shadows: [
      Shadow(color: AppColors.lavaOrange, blurRadius: 18),
      Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.parchment,
    letterSpacing: 0.8,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.parchment,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.parchment,
    letterSpacing: 1.1,
  );

  static const TextStyle scoreLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.lavaYellow,
    letterSpacing: 1.4,
  );

  static const TextStyle scoreValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: AppColors.parchment,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.obsidian,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.lavaOrange,
      brightness: Brightness.dark,
    ),
    fontFamily: AppTextStyles.fontFamily,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
