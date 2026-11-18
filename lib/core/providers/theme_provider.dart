import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme_constants.dart';

/// Notifier providing the currently active board theme ID ('tournament_green', 'classic_wood', 'midnight_dark').
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
