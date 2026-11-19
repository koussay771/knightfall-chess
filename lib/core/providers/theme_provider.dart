import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme_constants.dart';

// ─── Sound Theme ─────────────────────────────────────────────────────────────

/// Available sound theme names (must match folder names under assets/sound/).
const List<String> kSoundThemes = [
  'standard',
  'futuristic',
  'woodland',
  'piano',
  'sfx',
  'instrument',
  'lisp',
  'nes',
  'other',
  'robot',
];

class SoundThemeNotifier extends StateNotifier<String> {
  SoundThemeNotifier() : super('standard') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('sound_theme');
    if (saved != null && kSoundThemes.contains(saved)) {
      state = saved;
    }
  }

  Future<void> setTheme(String theme) async {
    if (!kSoundThemes.contains(theme)) return;
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sound_theme', theme);
  }
}

final soundThemeProvider = StateNotifierProvider<SoundThemeNotifier, String>(
  (ref) => SoundThemeNotifier(),
);

// ─── Board Theme ──────────────────────────────────────────────────────────────

/// Notifier providing the currently active board theme ID (e.g. 'green', 'blue-marble', 'wood', etc.).
class BoardThemeNotifier extends StateNotifier<String> {
  BoardThemeNotifier() : super('tournament_green') {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('board_theme');
    if (theme != null && AppThemes.boardThemes.containsKey(theme)) {
      state = theme;
    }
  }

  Future<void> setTheme(String themeId) async {
    if (AppThemes.boardThemes.containsKey(themeId)) {
      state = themeId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('board_theme', themeId);
    }
  }
}

final boardThemeProvider = StateNotifierProvider<BoardThemeNotifier, String>((ref) {
  return BoardThemeNotifier();
});

/// Notifier providing the currently active piece set ID (e.g. 'cburnett', 'alpha', 'staunty', etc.).
class PieceThemeNotifier extends StateNotifier<String> {
  PieceThemeNotifier() : super('cburnett') {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('piece_theme');
    if (theme != null && AppThemes.pieceThemes.containsKey(theme)) {
      state = theme;
    }
  }

  Future<void> setTheme(String themeId) async {
    if (AppThemes.pieceThemes.containsKey(themeId)) {
      state = themeId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('piece_theme', themeId);
    }
  }
}

final pieceThemeProvider = StateNotifierProvider<PieceThemeNotifier, String>((ref) {
  return PieceThemeNotifier();
});
