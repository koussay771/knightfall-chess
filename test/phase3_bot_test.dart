import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_hotspot/engine/bot_engine.dart';
import 'package:chess_hotspot/features/modes/dare_screen.dart';
import 'package:chess_hotspot/features/modes/koth_screen.dart';

void main() {
  group('Phase 3: 1500 ELO Chess Bot Tests', () {
    late ChessBot bot;

    setUp(() {
      bot = ChessBot(searchDepth: 2); // Depth 2 for super-fast unit testing
    });

    test('ChessBot generates legal opening move from initial FEN', () async {
      const initialFen =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final bestMove = await bot.findBestMove(initialFen);

      expect(bestMove, isNotNull);
      expect(bestMove!['from'], isNotNull);
      expect(bestMove['to'], isNotNull);
      // Valid white opening moves
      expect(['e2', 'd2', 'g1', 'c2', 'b1'].contains(bestMove['from']), true);
    });

    test('ChessBot finds immediate Mate-in-1', () async {
      // FEN: Scholar\'s mate setup — White Queen on h5, Bishop on c4, ready to play Qxf7#
      // rnbqkbnr/pppp1ppp/8/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 1
      const mateInOneFen =
          'rnbqkbnr/pppp1ppp/8/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 1';

      final bestMove = await bot.findBestMove(mateInOneFen);

      expect(bestMove, isNotNull);
      expect(bestMove!['from'], 'h5');
      expect(bestMove['to'], 'f7'); // Qxf7# mate!
    });

    test('ChessBot captures hanging Queen', () async {
      // Black Queen is hanging on e4, White Pawn on d3 can capture dxe4
      // 8/8/8/8/4q3/3P4/8/4K2k w - - 0 1
      const hangingQueenFen = '8/8/8/8/4q3/3P4/8/4K2k w - - 0 1';

      final bestMove = await bot.findBestMove(hangingQueenFen);

      expect(bestMove, isNotNull);
      expect(bestMove!['from'], 'd3');
      expect(bestMove['to'], 'e4'); // dxe4 captures Queen
    });

    test('ChessBot returns null when position is checkmate or draw', () async {
      // Checkmated position: 7k/5Q2/6K1/8/8/8/8/8 b - - 0 1 (Stalemate)
      const stalemateFen = '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1';
      final move = await bot.findBestMove(stalemateFen);
      expect(move, isNull);
    });
  });

  group('Phase 3: KOTH and Dare Mode UI Tests', () {
    testWidgets('KothScreen renders Leaderboard and Queue cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: KothScreen(),
        ),
      );

      expect(find.text('King of the Hill Tournament'), findsOneWidget);
      expect(find.text('Live Tournament Leaderboard'), findsOneWidget);
      expect(find.text('Up Next in Queue'), findsOneWidget);
      expect(find.text('King (Current Champion)'), findsOneWidget);
    });

    testWidgets('DareScreen allows selecting presets and entering custom dare',
        (tester) async {
      String? confirmedDare;

      await tester.pumpWidget(
        MaterialApp(
          home: DareScreen(
            onDareConfirmed: (d) => confirmedDare = d,
          ),
        ),
      );

      expect(find.text('Bet & Dare Challenge'), findsOneWidget);
      expect(find.text('Select a Preset Challenge'), findsOneWidget);

      // Tap preset
      await tester.tap(find.text('Loser buys coffee for the winner ☕'));
      await tester.pumpAndSettle();

      // Scroll to Confirm button and tap
      await tester.ensureVisible(find.text('Confirm Challenge'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Challenge'));
      await tester.pumpAndSettle();

      expect(confirmedDare, 'Loser buys coffee for the winner ☕');
    });
  });
}
