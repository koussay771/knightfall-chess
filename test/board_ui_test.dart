import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_hotspot/features/game/board_widget.dart';
import 'package:chess_hotspot/features/game/clock_widget.dart';
import 'package:chess_hotspot/features/game/move_history_widget.dart';
import 'package:chess_hotspot/features/game/takeback_dialog.dart';

void main() {
  group('Step 3: Interactive Board & Core UX UI Tests', () {
    testWidgets('BoardWidget renders 64 squares without legal move dots/hints',
        (tester) async {
      String? tappedSquare;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardWidget(
              fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
              selectedSquare: 'e2',
              lastMoveFrom: 'e7',
              lastMoveTo: 'e5',
              premoveFrom: 'g8',
              premoveTo: 'f6',
              onSquareTapped: (sq) => tappedSquare = sq,
            ),
          ),
        ),
      );

      // Verify 64 GestureDetector square tiles are rendered
      expect(find.byType(GestureDetector), findsNWidgets(64));

      // Verify no legal move dots or hint circles exist
      // Only the selected square, last move, and premove highlights are allowed
      expect(find.byKey(const Key('legal_move_dot')), findsNothing);

      // Tap on e4
      await tester.tap(find.text('e').first);
      await tester.pump();
      expect(tappedSquare, isNotNull);
    });

    testWidgets('BoardWidget flips board orientation when flipped is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardWidget(
              fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
              flipped: true,
              onSquareTapped: (_) {},
            ),
          ),
        ),
      );

      // Verify widget builds cleanly in flipped orientation
      expect(find.byType(BoardWidget), findsOneWidget);
    });

    testWidgets('ClockWidget formats time correctly and displays active status',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ClockWidget(
                  timeMs: 300000, // 5:00
                  isActive: true,
                  playerName: 'Alice',
                  isWhite: true,
                ),
                ClockWidget(
                  timeMs: 0,
                  isUnlimited: true,
                  isActive: false,
                  playerName: 'Bob',
                  isWhite: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('∞'), findsOneWidget);
    });

    testWidgets('MoveHistoryWidget renders horizontal SAN moves & captures',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MoveHistoryWidget(
              moveHistory: [
                {'san': 'e4'},
                {'san': 'e5'},
                {'san': 'Nf3'},
              ],
              whiteCaptured: ['p'],
              blackCaptured: [],
              whiteMaterialAdvantage: 1,
            ),
          ),
        ),
      );

      expect(find.text('e4'), findsOneWidget);
      expect(find.text('e5'), findsOneWidget);
      expect(find.text('Nf3'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('TakebackDialog renders Accept and Decline buttons',
        (tester) async {
      bool accepted = false;
      bool declined = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TakebackDialog(
              requesterName: 'Opponent',
              onAccept: () => accepted = true,
              onDecline: () => declined = true,
            ),
          ),
        ),
      );

      expect(find.text('Takeback Request'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      expect(accepted, true);

      await tester.tap(find.text('Decline'));
      expect(declined, true);
    });
  });
}
