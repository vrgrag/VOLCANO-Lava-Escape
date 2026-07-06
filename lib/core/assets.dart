/// Centralized asset path constants so filenames only live in one place.
class AppAssets {
  AppAssets._();

  static const String _base = 'assets';

  static const String icon = '$_base/Icon_asset.png';
  static const String logo = '$_base/lava_escape_logo_asset.webp';
  static const String backgroundDark = '$_base/volcano_background_dark_asset.webp';
  static const String loadingVertical = '$_base/Vertical_Loading_Screen.webp';
  static const String loadingHorizontal = '$_base/Horizontal_Loading_Screen.webp';

  static const String runeArrow = '$_base/arrow_rune_asset.webp';
  static const String runeCircle = '$_base/circle_rune_asset.webp';
  static const String runeCross = '$_base/cross_rune_asset.webp';
  static const String runeDiamond = '$_base/diamond_rune_asset.webp';
  static const String runeHeart = '$_base/heart_rune_asset.webp';
  static const String runeSquare = '$_base/square_rune_asset.webp';
  static const String runeStar = '$_base/star_rune_asset.webp';
  static const String runeTriangle = '$_base/triangle_rune_asset.webp';

  /// All images that should be pre-cached on the loading screen.
  static const List<String> precacheImages = [
    logo,
    backgroundDark,
    loadingVertical,
    loadingHorizontal,
    runeArrow,
    runeCircle,
    runeCross,
    runeDiamond,
    runeHeart,
    runeSquare,
    runeStar,
    runeTriangle,
  ];
}
