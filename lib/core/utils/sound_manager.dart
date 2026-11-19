import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Themed sound and haptic feedback manager for Knightfall Chess.
///
/// Sound files live at:  assets/sound/{theme}/{Name}.mp3
/// e.g.  assets/sound/standard/Move.mp3
///       assets/sound/futuristic/Capture.mp3
///
/// Call [setTheme] whenever the user switches their sound pack.
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  // Two players: one for quick SFX (move/capture/check), one for end-game.
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _endPlayer = AudioPlayer();

  bool soundEnabled = true;
  String _theme = 'standard';

  void setTheme(String theme) => _theme = theme;
  String get currentTheme => _theme;

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _asset(String name) => 'sound/$_theme/$name.mp3';

  Future<void> _play(AudioPlayer player, String name) async {
    if (!soundEnabled) return;
    try {
      await player.stop();
      await player.play(AssetSource(_asset(name)));
    } catch (_) {
      // Silently ignore missing asset or platform error.
    }
  }

  // ─── Gameplay sounds ───────────────────────────────────────────────────────

  /// Normal piece move.
  Future<void> playMove() async {
    HapticFeedback.lightImpact();
    await _play(_sfxPlayer, 'Move');
  }

  /// Piece captured.
  Future<void> playCapture() async {
    HapticFeedback.mediumImpact();
    await _play(_sfxPlayer, 'Capture');
  }

  /// King put in check.
  Future<void> playCheck() async {
    HapticFeedback.heavyImpact();
    await _play(_sfxPlayer, 'Check');
  }

  /// Checkmate delivered.
  Future<void> playCheckmate() async {
    HapticFeedback.heavyImpact();
    await _play(_endPlayer, 'Checkmate');
  }

  /// Illegal move attempted.
  Future<void> playIllegalMove() async {
    HapticFeedback.vibrate();
    await _play(_sfxPlayer, 'Error');
  }

  /// Player wins.
  Future<void> playVictory() async {
    await _play(_endPlayer, 'Victory');
  }

  /// Player loses.
  Future<void> playDefeat() async {
    await _play(_endPlayer, 'Defeat');
  }

  /// Game ends in a draw.
  Future<void> playDraw() async {
    await _play(_endPlayer, 'Draw');
  }

  /// Generic game-over (fallback when win/loss/draw not distinguished).
  Future<void> playGameOver() async {
    await _play(_endPlayer, 'Checkmate');
  }

  /// Takeback accepted.
  Future<void> playTakeback() async {
    await _play(_sfxPlayer, 'Confirmation');
  }

  /// Match or game starting (lobby countdown done).
  Future<void> playGameStart() async {
    await _play(_sfxPlayer, 'Confirmation');
  }

  /// Clock running low (< 30 s).
  Future<void> playLowTime() async {
    await _play(_sfxPlayer, 'LowTime');
  }

  // ─── Networking / lobby sounds ─────────────────────────────────────────────

  /// A new player joined the hosted room.
  Future<void> playClientConnected() async {
    await _play(_sfxPlayer, 'GenericNotify');
  }

  /// Host server started successfully.
  Future<void> playHostStarted() async {
    await _play(_sfxPlayer, 'NewChallenge');
  }

  /// WebSocket / network connection lost.
  Future<void> playConnectionLost() async {
    HapticFeedback.heavyImpact();
    await _play(_sfxPlayer, 'Error');
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────────

  void dispose() {
    try {
      _sfxPlayer.dispose();
      _endPlayer.dispose();
    } catch (_) {}
  }
}
