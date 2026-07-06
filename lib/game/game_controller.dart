import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/rune.dart';
import '../services/storage_service.dart';

enum GameStatus {
  idle,
  showingSequence,
  playerTurn,
  levelTransition,
  gameOver,
}

/// Drives the Memory / Simon-Says rune sequence game:
/// generation, playback with highlight timing, input validation,
/// scoring, difficulty scaling and best-score persistence.
class GameController extends ChangeNotifier {
  GameController(this._storage);

  final StorageService _storage;
  final Random _rng = Random();

  static const Duration gapDuration = Duration(milliseconds: 250);
  static const Duration feedbackDuration = Duration(milliseconds: 220);
  static const Duration levelTransitionDelay = Duration(milliseconds: 650);

  final List<Rune> _sequence = [];
  List<Rune> get sequence => List.unmodifiable(_sequence);

  GameStatus status = GameStatus.idle;
  int score = 0;
  int playerProgress = 0;
  int highlightedIndex = -1;
  Rune? feedbackRune;
  bool feedbackIsError = false;
  bool isPaused = false;

  bool _disposed = false;
  int _runToken = 0;

  int get bestScore => _storage.bestScore;
  bool get isNewBest => score > 0 && score >= _storage.bestScore;

  /// Level currently being attempted (1-indexed). Sequence length = level + 1.
  int get level => score + 1;

  Duration get highlightDuration {
    if (level <= 5) return const Duration(milliseconds: 800);
    if (level <= 10) return const Duration(milliseconds: 700);
    return const Duration(milliseconds: 600);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> startGame() async {
    final token = ++_runToken;
    _sequence.clear();
    score = 0;
    playerProgress = 0;
    highlightedIndex = -1;
    feedbackRune = null;
    feedbackIsError = false;
    isPaused = false;
    status = GameStatus.showingSequence;
    _addRandomRune();
    _addRandomRune();
    _safeNotify();
    await _playSequence(token);
  }

  Rune _generateNextRune() {
    Rune next;
    do {
      next = Rune.values[_rng.nextInt(Rune.values.length)];
    } while (_sequence.length >= 2 &&
        _sequence[_sequence.length - 1] == next &&
        _sequence[_sequence.length - 2] == next);
    return next;
  }

  void _addRandomRune() {
    _sequence.add(_generateNextRune());
  }

  void pause() {
    if (status == GameStatus.gameOver) return;
    isPaused = true;
    _safeNotify();
  }

  void resume() {
    isPaused = false;
    _safeNotify();
  }

  /// Cancelable delay that respects pause state and aborts if a newer
  /// game run has started (e.g. after a restart) or the controller died.
  Future<bool> _wait(Duration total, int token) async {
    const step = Duration(milliseconds: 16);
    Duration elapsed = Duration.zero;
    while (elapsed < total) {
      if (_disposed || token != _runToken) return false;
      if (isPaused) {
        await Future.delayed(step);
        continue;
      }
      final remaining = total - elapsed;
      final thisStep = remaining < step ? remaining : step;
      await Future.delayed(thisStep);
      elapsed += thisStep;
    }
    return !_disposed && token == _runToken;
  }

  Future<void> _playSequence(int token) async {
    status = GameStatus.showingSequence;
    playerProgress = 0;
    highlightedIndex = -1;
    _safeNotify();

    if (!await _wait(const Duration(milliseconds: 400), token)) return;

    for (var i = 0; i < _sequence.length; i++) {
      if (token != _runToken || _disposed) return;
      highlightedIndex = i;
      _safeNotify();
      if (!await _wait(highlightDuration, token)) return;
      highlightedIndex = -1;
      _safeNotify();
      if (!await _wait(gapDuration, token)) return;
    }

    if (token != _runToken || _disposed) return;
    status = GameStatus.playerTurn;
    playerProgress = 0;
    _safeNotify();
  }

  Future<void> onRuneTap(Rune tapped) async {
    if (status != GameStatus.playerTurn || isPaused) return;
    final token = _runToken;

    final expected = _sequence[playerProgress];
    if (tapped != expected) {
      feedbackRune = tapped;
      feedbackIsError = true;
      status = GameStatus.gameOver;
      _safeNotify();
      await _storage.submitScore(score);
      return;
    }

    feedbackRune = tapped;
    feedbackIsError = false;
    _safeNotify();
    await _wait(feedbackDuration, token);
    if (token != _runToken || _disposed) return;
    feedbackRune = null;
    _safeNotify();

    playerProgress++;
    if (playerProgress >= _sequence.length) {
      score++;
      await _storage.submitScore(score);
      status = GameStatus.levelTransition;
      _safeNotify();
      _addRandomRune();
      if (!await _wait(levelTransitionDelay, token)) return;
      await _playSequence(token);
    }
  }

  Future<void> restart() => startGame();
}
