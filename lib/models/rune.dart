import '../core/assets.dart';

/// The 8 volcanic runes used by the memory sequence.
enum Rune {
  circle,
  square,
  triangle,
  diamond,
  star,
  cross,
  heart,
  arrow,
}

extension RuneAsset on Rune {
  String get assetPath {
    switch (this) {
      case Rune.circle:
        return AppAssets.runeCircle;
      case Rune.square:
        return AppAssets.runeSquare;
      case Rune.triangle:
        return AppAssets.runeTriangle;
      case Rune.diamond:
        return AppAssets.runeDiamond;
      case Rune.star:
        return AppAssets.runeStar;
      case Rune.cross:
        return AppAssets.runeCross;
      case Rune.heart:
        return AppAssets.runeHeart;
      case Rune.arrow:
        return AppAssets.runeArrow;
    }
  }

  String get label {
    switch (this) {
      case Rune.circle:
        return 'Circle';
      case Rune.square:
        return 'Square';
      case Rune.triangle:
        return 'Triangle';
      case Rune.diamond:
        return 'Diamond';
      case Rune.star:
        return 'Star';
      case Rune.cross:
        return 'Cross';
      case Rune.heart:
        return 'Heart';
      case Rune.arrow:
        return 'Arrow';
    }
  }
}
