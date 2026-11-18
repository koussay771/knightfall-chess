import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_hotspot/core/constants/theme_constants.dart';
import 'package:chess_hotspot/core/providers/theme_provider.dart';
import 'package:chess_hotspot/features/profile_themes/profile_screen.dart';
import 'package:chess_hotspot/features/profile_themes/theme_screen.dart';
import 'package:chess_hotspot/features/game/board_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'player_name': 'Grandmaster',
      'player_avatar': '🦁',
      'player_color': 0xFF89B4FA,
      'board_theme': 'midnight_dark',
    });
  });

  test('BoardThemes map contains classic_wood, tournament_green, midnight_dark', () {
    expect(AppThemes.boardThemes.containsKey('classic_wood'), isTrue);
    expect(AppThemes.boardThemes.containsKey('tournament_green'), isTrue);
    expect(AppThemes.boardThemes.containsKey('midnight_dark'), isTrue);
    expect(AppThemes.boardThemes['classic_wood']!.length, 2);
  });

  test('BoardThemeNotifier initializes and updates theme cleanly', () async {
    final notifier = BoardThemeNotifier();
    expect(notifier.state, 'tournament_green');

    await notifier.setTheme('classic_wood');
    expect(notifier.state, 'classic_wood');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('board_theme'), 'classic_wood');
  });

  testWidgets('ThemeScreen renders theme options and allows selecting theme',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ThemeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Board Themes'), findsOneWidget);
    expect(find.text('Classic Wood'), findsOneWidget);
    expect(find.text('Tournament Green'), findsOneWidget);
    expect(find.text('Midnight Dark'), findsOneWidget);

    // Tap on Classic Wood
    await tester.tap(find.text('Classic Wood'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('board_theme'), 'classic_wood');
  });

  testWidgets('ProfileScreen renders and saves customized profile',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Player Profile & Customization'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Change player name
    await tester.enterText(find.byType(TextField), 'Magnus');
    await tester.pumpAndSettle();

    // Select avatar emoji
    await tester.tap(find.text('👑'));
    await tester.pumpAndSettle();

    // Ensure Save Profile button is visible and tap it
    await tester.ensureVisible(find.text('Save Profile'));
    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('player_name'), 'Magnus');
    expect(prefs.getString('player_avatar'), '👑');
  });

  testWidgets('BoardWidget renders with custom light and dark square colors',
      (WidgetTester tester) async {
    const customLight = Color(0xFFF0D9B5);
    const customDark = Color(0xFFB58863);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardWidget(
            fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            lightSquareColor: customLight,
            darkSquareColor: customDark,
            selectedSquare: 'e2',
            onSquareTapped: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BoardWidget), findsOneWidget);
    // Square 'e2' has pawn '♙'
    expect(find.text('♙'), findsNWidgets(8));
  });
}
