import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for the small set of values
/// this game persists locally (fully offline, no network required).
class StorageService {
  StorageService._(this._prefs);

  static const String _kBestScore = 'best_score';
  static const String _kSoundEnabled = 'sound_enabled';

  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  int get bestScore => _prefs.getInt(_kBestScore) ?? 0;

  /// Persists [score] as the new best if it beats the current record.
  /// Returns true if a new record was set.
  Future<bool> submitScore(int score) async {
    if (score > bestScore) {
      await _prefs.setInt(_kBestScore, score);
      return true;
    }
    return false;
  }

  bool get soundEnabled => _prefs.getBool(_kSoundEnabled) ?? true;

  Future<void> setSoundEnabled(bool value) =>
      _prefs.setBool(_kSoundEnabled, value);
}
