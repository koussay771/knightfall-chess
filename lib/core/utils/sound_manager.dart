import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../constants/theme_constants.dart';

/// Themed sound and haptic feedback manager for Knightfall Chess.
///
/// Sound resolution priority:
/// 1. Special Piece Override: If active piece style is 'anarcandy',
///    always use `assets/sound/anarcandy/` with strict per-piece mapping.
/// 2. Board Theme Match: Otherwise look for folder in `assets/sound/`
///    with exact same name as selected board theme (e.g. `assets/sound/wood/`).
/// 3. Fallback: Automatically fall back to `assets/sound/default/`.
///
/// Anarcandy strict mapping (no random fallback):
///   Checkmate:    checkmate.mp3
///   Check:        pipi-move.mp3
///   Castle:       brick-castle.mp3
///   En Passant:   en-passant.mp3
///   Capture:      bishop→pipi-take  knight→horsy-take  rook→brick-take
///                 pawn→toy-take     queen→death-take   king→cone-take
///   Normal Move:  bishop→hit        knight→horsy-move  rook→brick-move
///                 pawn→toy-move     queen→death-move   king→cone-move
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _endPlayer = AudioPlayer();

  bool soundEnabled = true;

  String _boardTheme = 'green';
  String _pieceTheme = 'cburnett';

  static const Set<String> _availableFolders = {
    'anarcandy',
    'beat',
    'blue-marble',
    'canvas2',
    'default',
    'futuristic',
    'green',
    'instrument',
    'lolz',
    'metal',
    'metal1',
    'nes',
    'newspaper',
    'piano',
    'robot',
    'sfx',
    'silly',
    'standard',
    'wood',
  };

  void updateThemes({String? boardTheme, String? pieceTheme}) {
    if (boardTheme != null) _boardTheme = boardTheme;
    if (pieceTheme != null) _pieceTheme = pieceTheme;
  }

  void setTheme(String theme) {
    _boardTheme = theme;
  }

  String get currentTheme => resolveActiveFolder();

  /// Resolves active sound folder according to priority rules:
  /// 1. Special piece style 'anarcandy' -> 'anarcandy'
  /// 2. Matching board theme folder in assets/sound/
  /// 3. Fallback -> 'default'
  String resolveActiveFolder() {
    if (_pieceTheme.toLowerCase() == 'anarcandy') return 'anarcandy';

    final raw = _boardTheme.toLowerCase();
    if (_availableFolders.contains(raw)) return raw;

    final dashed = raw.replaceAll('_', '-');
    if (_availableFolders.contains(dashed)) return dashed;

    try {
      final canonical = AppThemes.getBoardTheme(_boardTheme).id.toLowerCase();
      if (_availableFolders.contains(canonical)) return canonical;
      if (canonical == 'brown' && _availableFolders.contains('wood')) {
        return 'wood';
      }
    } catch (_) {}

    return 'default';
  }

  // ─── Anarcandy Strict Per-Piece Mapping ────────────────────────────────────

  /// Returns the single exact anarcandy filename for the given event.
  /// No random selection — every event maps to exactly one file.
  String _anarcandyFile(String event) {
    switch (event) {
      // Terminal / special
      case 'checkmate':      return 'checkmate.mp3';
      case 'check':          return 'pipi-move.mp3';
      case 'castle':         return 'brick-castle.mp3';
      case 'en-passant':     return 'en-passant.mp3';

      // Per-piece captures (moving piece type)
      case 'capture-bishop': return 'pipi-take.mp3';
      case 'capture-knight': return 'horsy-take.mp3';
      case 'capture-rook':   return 'brick-take.mp3';
      case 'capture-pawn':   return 'toy-take.mp3';
      case 'capture-queen':  return 'death-take.mp3';
      case 'capture-king':   return 'cone-take.mp3';
      case 'capture':        return 'brick-take.mp3';  // generic fallback

      // Per-piece normal moves
      case 'move-bishop':    return 'hit.mp3';
      case 'move-knight':    return 'horsy-move.mp3';
      case 'move-rook':      return 'brick-move.mp3';
      case 'move-pawn':      return 'toy-move.mp3';
      case 'move-queen':     return 'death-move.mp3';
      case 'move-king':      return 'cone-move.mp3';
      case 'move':           return 'brick-move.mp3';  // generic fallback

      // Other UI events
      case 'promote':        return 'toy-move.mp3';
      case 'game-start':     return 'toy-move.mp3';
      case 'game-end':
      case 'victory':
      case 'draw':           return 'checkmate.mp3';
      case 'defeat':         return 'death-move.mp3';
      case 'illegal':        return 'death-move.mp3';
      case 'low-time':       return 'hit.mp3';
      case 'premove':        return 'brick-move.mp3';
      case 'takeback':       return 'toy-move.mp3';
      case 'lobby-join':     return 'toy-move.mp3';
      default:               return 'brick-move.mp3';
    }
  }

  // ─── Sound Asset Filename Resolution ───────────────────────────────────────

  List<String> _candidatesForEvent(String folder, String event) {
    if (folder == 'anarcandy') {
      // Single exact file — no random selection.
      return [_anarcandyFile(event)];
    }

    // For non-anarcandy themes, strip the piece-type suffix so we look up the
    // generic 'move' or 'capture' sound (they don't have per-piece audio).
    final baseEvent = _stripPieceSuffix(event);

    // Lichess-style lowercase naming:
    // (default, green, blue-marble, canvas2, beat, lolz, metal, newspaper, silly)
    const lichessFolders = {
      'default', 'green', 'blue-marble', 'canvas2',
      'beat', 'lolz', 'metal', 'newspaper', 'silly',
    };

    if (lichessFolders.contains(folder)) {
      switch (baseEvent) {
        case 'move':      return ['move-self.mp3', 'move-opponent.mp3', 'Move.mp3'];
        case 'capture':   return ['capture.mp3', 'Capture.mp3'];
        case 'check':     return ['move-check.mp3', 'Check.mp3'];
        case 'castle':    return ['castle.mp3', 'move-self.mp3', 'Move.mp3'];
        case 'promote':   return ['promote.mp3', 'move-self.mp3', 'Move.mp3'];
        case 'game-start':return ['game-start.mp3', 'Confirmation.mp3', 'NewChallenge.mp3'];
        case 'game-end':
        case 'checkmate':
        case 'victory':   return ['game-end.mp3', 'Checkmate.mp3', 'Victory.mp3'];
        case 'defeat':    return ['game-end.mp3', 'Defeat.mp3'];
        case 'draw':      return ['drawoffer.mp3', 'game-end.mp3', 'Draw.mp3'];
        case 'illegal':   return ['illegal.mp3', 'Error.mp3'];
        case 'low-time':  return ['tenseconds.mp3', 'LowTime.mp3'];
        case 'premove':   return ['premove.mp3', 'move-self.mp3', 'Move.mp3'];
        case 'takeback':  return ['drawoffer.mp3', 'Confirmation.mp3', 'move-self.mp3'];
        case 'lobby-join':return ['game-start.mp3', 'GenericNotify.mp3'];
        default:          return ['move-self.mp3', 'Move.mp3'];
      }
    }

    // Capitalized-style naming:
    // (standard, wood, futuristic, instrument, metal1, nes, piano, robot, sfx)
    switch (baseEvent) {
      case 'move':      return ['Move.mp3', 'move-self.mp3'];
      case 'capture':   return ['Capture.mp3', 'capture.mp3'];
      case 'check':     return ['Check.mp3', 'move-check.mp3'];
      case 'castle':    return ['Move.mp3', 'castle.mp3'];
      case 'promote':   return ['Move.mp3', 'promote.mp3'];
      case 'game-start':return ['Confirmation.mp3', 'NewChallenge.mp3', 'game-start.mp3'];
      case 'game-end':
      case 'checkmate': return ['Checkmate.mp3', 'game-end.mp3'];
      case 'victory':   return ['Victory.mp3', 'Checkmate.mp3', 'game-end.mp3'];
      case 'defeat':    return ['Defeat.mp3', 'game-end.mp3'];
      case 'draw':      return ['Draw.mp3', 'drawoffer.mp3', 'game-end.mp3'];
      case 'illegal':   return ['Error.mp3', 'illegal.mp3'];
      case 'low-time':  return ['LowTime.mp3', 'tenseconds.mp3'];
      case 'premove':   return ['Move.mp3', 'premove.mp3'];
      case 'takeback':  return ['Confirmation.mp3', 'drawoffer.mp3'];
      case 'lobby-join':return ['GenericNotify.mp3', 'NewChallenge.mp3'];
      default:          return ['Move.mp3'];
    }
  }

  /// Strips piece-type suffix for non-anarcandy themes.
  /// 'move-knight' → 'move', 'capture-pawn' → 'capture', 'en-passant' → 'capture'
  static String _stripPieceSuffix(String event) {
    if (event.startsWith('move-')) return 'move';
    if (event.startsWith('capture-')) return 'capture';
    if (event == 'en-passant') return 'capture';
    return event;
  }

  Future<void> _playEvent(AudioPlayer player, String event) async {
    if (!soundEnabled) return;
    final folder = resolveActiveFolder();
    final candidates = _candidatesForEvent(folder, event);

    // Always use candidates.first — for anarcandy this is the single exact file.
    final filename = candidates.first;
    final primaryPath = 'sound/$folder/$filename';

    try {
      await player.stop();
      await player.play(AssetSource(primaryPath));
      return;
    } catch (_) {
      // Primary failed — try fallback folder
    }

    final fallbackFolder = folder == 'default' ? 'standard' : 'default';
    final fallbackCandidates = _candidatesForEvent(fallbackFolder, event);
    final fallbackFile = fallbackCandidates.isNotEmpty
        ? fallbackCandidates.first
        : 'move-self.mp3';

    try {
      await player.stop();
      await player.play(AssetSource('sound/$fallbackFolder/$fallbackFile'));
    } catch (_) {}
  }

  // ─── Helpers: derive event from piece type char ─────────────────────────────

  /// Converts a chess.js-style piece char ('p','n','b','r','q','k')
  /// to the move event name.
  static String _moveEvent(String? pieceType) {
    switch (pieceType?.toLowerCase()) {
      case 'p': return 'move-pawn';
      case 'n': return 'move-knight';
      case 'b': return 'move-bishop';
      case 'r': return 'move-rook';
      case 'q': return 'move-queen';
      case 'k': return 'move-king';
      default:  return 'move';
    }
  }

  /// Converts a chess.js-style piece char to the capture event name.
  static String _captureEvent(String? pieceType) {
    switch (pieceType?.toLowerCase()) {
      case 'p': return 'capture-pawn';
      case 'n': return 'capture-knight';
      case 'b': return 'capture-bishop';
      case 'r': return 'capture-rook';
      case 'q': return 'capture-queen';
      case 'k': return 'capture-king';
      default:  return 'capture';
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Play a normal move sound.
  /// [pieceType] — chess.js piece char: 'p' 'n' 'b' 'r' 'q' 'k'.
  ///   Only used by anarcandy; other themes play their generic move sound.
  /// [isCastle], [isEnPassant], [isPromotion] override piece-based selection.
  Future<void> playMove({
    bool isCastle = false,
    bool isPromotion = false,
    bool isEnPassant = false,
    String? pieceType,
  }) async {
    HapticFeedback.lightImpact();
    if (isCastle) {
      await _playEvent(_sfxPlayer, 'castle');
    } else if (isEnPassant) {
      await _playEvent(_sfxPlayer, 'en-passant');
    } else if (isPromotion) {
      await _playEvent(_sfxPlayer, 'promote');
    } else {
      await _playEvent(_sfxPlayer, _moveEvent(pieceType));
    }
  }

  /// Play a capture sound.
  /// [pieceType] — the piece *performing* the capture.
  /// [isEnPassant] — overrides to en-passant sound.
  Future<void> playCapture({
    String? pieceType,
    bool isEnPassant = false,
  }) async {
    HapticFeedback.mediumImpact();
    if (isEnPassant) {
      await _playEvent(_sfxPlayer, 'en-passant');
    } else {
      await _playEvent(_sfxPlayer, _captureEvent(pieceType));
    }
  }

  Future<void> playCheck() async {
    HapticFeedback.heavyImpact();
    await _playEvent(_sfxPlayer, 'check');
  }

  Future<void> playCastle() async {
    HapticFeedback.lightImpact();
    await _playEvent(_sfxPlayer, 'castle');
  }

  Future<void> playPromotion() async {
    HapticFeedback.mediumImpact();
    await _playEvent(_sfxPlayer, 'promote');
  }

  Future<void> playPremove() async {
    HapticFeedback.selectionClick();
    await _playEvent(_sfxPlayer, 'premove');
  }

  Future<void> playCheckmate() async {
    HapticFeedback.heavyImpact();
    await _playEvent(_endPlayer, 'checkmate');
  }

  Future<void> playIllegalMove() async {
    HapticFeedback.vibrate();
    await _playEvent(_sfxPlayer, 'illegal');
  }

  Future<void> playVictory() async {
    await _playEvent(_endPlayer, 'victory');
  }

  Future<void> playDefeat() async {
    await _playEvent(_endPlayer, 'defeat');
  }

  Future<void> playDraw() async {
    await _playEvent(_endPlayer, 'draw');
  }

  Future<void> playGameOver() async {
    await _playEvent(_endPlayer, 'game-end');
  }

  Future<void> playTakeback() async {
    await _playEvent(_sfxPlayer, 'takeback');
  }

  Future<void> playGameStart() async {
    await _playEvent(_sfxPlayer, 'game-start');
  }

  Future<void> playLowTime() async {
    await _playEvent(_sfxPlayer, 'low-time');
  }

  Future<void> playClientConnected() async {
    await _playEvent(_sfxPlayer, 'lobby-join');
  }

  Future<void> playHostStarted() async {
    await _playEvent(_sfxPlayer, 'game-start');
  }

  Future<void> playConnectionLost() async {
    HapticFeedback.heavyImpact();
    await _playEvent(_sfxPlayer, 'illegal');
  }

  void dispose() {
    try {
      _sfxPlayer.dispose();
      _endPlayer.dispose();
    } catch (_) {}
  }
}
