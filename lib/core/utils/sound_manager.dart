import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Sound and haptic manager for interactive chess feedback.
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  final AudioPlayer _player = AudioPlayer();
  bool soundEnabled = true;

  Future<void> playMove() async {
    HapticFeedback.lightImpact();
    if (!soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/move.mp3'));
    } catch (_) {
      // Audio asset fallback / silent ignore
    }
  }

  Future<void> playCapture() async {
    HapticFeedback.mediumImpact();
    if (!soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/capture.mp3'));
    } catch (_) {
      // Audio asset fallback / silent ignore
    }
  }

  Future<void> playCheck() async {
    HapticFeedback.heavyImpact();
    if (!soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/check.mp3'));
    } catch (_) {
      // Audio asset fallback / silent ignore
    }
  }

  Future<void> playIllegalMove() async {
    HapticFeedback.vibrate();
    if (!soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/illegal.mp3'));
    } catch (_) {
      // Audio asset fallback / silent ignore
    }
  }

  Future<void> playGameOver() async {
    HapticFeedback.heavyImpact();
    if (!soundEnabled) return;
    try {
      await _player.play(AssetSource('sounds/game_over.mp3'));
    } catch (_) {
      // Audio asset fallback / silent ignore
    }
  }

  void dispose() {
    try {
      _player.dispose();
    } catch (_) {}
  }
}
