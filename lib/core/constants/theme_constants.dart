import 'package:flutter/material.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────
// Strict "Board-First" dark charcoal with Neon Green and Gold accents
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg0 = Color(0xFF0D0D0F); // deepest background
  static const Color bg1 = Color(0xFF141416); // scaffold
  static const Color bg2 = Color(0xFF1A1A1D); // card surface
  static const Color bg3 = Color(0xFF222226); // elevated card

  // Neon Green accents
  static const Color neonGreen = Color(0xFF39FF7E);
  static const Color neonGreenDim = Color(0xFF27C45C);
  static const Color neonGreenFaint = Color(0x2039FF7E);

  // Gold accents
  static const Color gold = Color(0xFFFFCC02);
  static const Color goldDim = Color(0xFFE5A800);
  static const Color goldFaint = Color(0x22FFCC02);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F2);
  static const Color textSecondary = Color(0xFF8C8C9A);
  static const Color textDim = Color(0xFF55555E);

  // Borders / Dividers
  static const Color border = Color(0xFF2A2A30);
  static const Color borderBright = Color(0xFF3A3A44);

  // Semantic
  static const Color win = Color(0xFF39FF7E);
  static const Color loss = Color(0xFFFF3B5C);
  static const Color draw = Color(0xFF8C8C9A);
  static const Color check = Color(0xFFFF1744);
}

// ─── Design Tokens ────────────────────────────────────────────────────────────
class AppDimensions {
  AppDimensions._();

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;

  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(14.0);
}

// ─── App Theme ────────────────────────────────────────────────────────────────
class AppThemes {
  AppThemes._();

  static const Map<String, List<Color>> boardThemes = {
    'cyber_slate': [Color(0xFFCFD8DC), Color(0xFF16202C)],
    'tactical_dark': [Color(0xFF242A33), Color(0xFF161C24)],
    'classic_wood': [Color(0xFFF0D9B5), Color(0xFFB58863)],
    'tournament_green': [Color(0xFFEEEED2), Color(0xFF769656)],
    'midnight_dark': [Color(0xFF4A4A6A), Color(0xFF1E1E3A)],
    'neon_night': [Color(0xFF1C2535), Color(0xFF0D1520)],
  };

  static const Map<String, String> pieceThemes = {
    'tactical': 'Tactical Grandmaster',
    'classic': 'Classic Woodcraft',
    'neon_phosphor': 'Cyber Neon',
    'obsidian': 'Obsidian Stealth',
  };

  static ThemeData get darkTheme => ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonGreen,
          secondary: AppColors.gold,
          surface: AppColors.bg2,
          onPrimary: AppColors.bg1,
          onSecondary: AppColors.bg1,
          onSurface: AppColors.textPrimary,
          error: AppColors.loss,
        ),
        scaffoldBackgroundColor: AppColors.bg1,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg1,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.bg2,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusMedium),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.bg3,
          selectedColor: AppColors.neonGreenFaint,
          side: const BorderSide(color: AppColors.border),
          labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          bodySmall: TextStyle(
            color: AppColors.textDim,
            fontSize: 11,
          ),
          labelSmall: TextStyle(
            color: AppColors.textDim,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        useMaterial3: true,
        dividerColor: AppColors.border,
      );
}
