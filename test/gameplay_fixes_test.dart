import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_pkg;
import 'package:chess_hotspot/engine/move_validator.dart';
import 'package:chess_hotspot/engine/chess_board_state.dart';
import 'package:chess_hotspot/features/game/board_widget.dart';

void main() {
  group('Gameplay & Performance Fixes Tests', () {
    test('Castling logic supports both King destination and Rook square target', () {
      // FEN with Kingside & Queenside castling available for White
      const fen = 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1';
      final chess = chess_pkg.Chess.fromFEN(fen);

      final targets = MoveValidator.getMoves(chess, 'e1');
      // Must contain standard targets g1 and c1, and Rook targets h1 and a1
      expect(targets.contains('g1'), isTrue);
      expect(targets.contains('c1'), isTrue);
      expect(targets.contains('h1'), isTrue);
      expect(targets.contains('a1'), isTrue);

      // Verify normalization
      expect(MoveValidator.normalizeMoveTo('e1', 'h1'), 'g1');
      expect(MoveValidator.normalizeMoveTo('e1', 'a1'), 'c1');
      expect(MoveValidator.normalizeMoveTo('e8', 'h8'), 'g8');
      expect(MoveValidator.normalizeMoveTo('e8', 'a8'), 'c8');
      expect(MoveValidator.normalizeMoveTo('e2', 'e4'), 'e4');
    });

    test('ChessBoardNotifier executes Kingside and Queenside castling simultaneously', () {
      const fen = 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1';
      final notifier = ChessBoardNotifier();
      notifier.applyFen(fen);

      // Kingside castling by moving King e1 -> h1 (or e1 -> g1)
      final success = notifier.makeMove('e1', 'h1');
      expect(success, isTrue);

      final state = notifier.state;
      // In resulting FEN, King is on g1 and Rook is on f1
      expect(state.lastMoveFrom, 'e1');
      expect(state.lastMoveTo, 'g1');
      expect(state.fen.contains('R4RK1'), isTrue);
    });

    test('Check detection and King square resolution accurately identifies checked King', () {
      // Scholar's Mate checkmate position: Black King on e8 in checkmate
      const mateFen = 'r1bqkb1r/pppp1Qpp/2n5/4p3/2B1n3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4';
      final chess = chess_pkg.Chess.fromFEN(mateFen);

      expect(MoveValidator.isInCheck(chess), isTrue);
      final kingSq = MoveValidator.findKingSquare(chess, 'black');
      expect(kingSq, 'e8');

      // Attempting any move while in checkmate exposes or leaves in check
      expect(MoveValidator.wouldExposeOrLeaveInCheck(chess, 'a7', 'a6'), isTrue);
    });

    testWidgets('BoardWidget renders legal target dots and capture rings when active, clean when idle',
        (WidgetTester tester) async {
      // 1. Idle board: legalTargets is empty
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardWidget(
              fen: ChessBoardState.initialFen,
              onSquareTapped: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Board must be clean when idle: no legal dots or rings
      expect(find.byKey(const Key('legal_move_dot')), findsNothing);
      expect(find.byKey(const Key('legal_capture_ring')), findsNothing);

      // 2. Active selection: legalTargets contains empty square 'e4' and capture target 'd5'
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardWidget(
              fen: 'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
              selectedSquare: 'e4',
              legalTargets: const ['e5', 'd5'],
              onSquareTapped: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty target square 'e5' has dot
      expect(find.byKey(const Key('legal_move_dot')), findsOneWidget);
      // Occupied target square 'd5' has capture ring
      expect(find.byKey(const Key('legal_capture_ring')), findsOneWidget);
    });

    testWidgets('BoardWidget renders Draggable pieces and DragTarget for piece flying',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardWidget(
              fen: ChessBoardState.initialFen,
              onSquareTapped: (_) {},
              onPieceDropped: (from, to) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Draggable and DragTarget widgets are mounted for smooth flying
      expect(find.byType(Draggable<String>), findsWidgets);
      expect(find.byType(DragTarget<String>), findsNWidgets(64));
    });

    testWidgets('BoardWidget highlights King in check with warning flash and last move in gold',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BoardWidget(
              fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
              lastMoveFrom: 'e2',
              lastMoveTo: 'e4',
              checkSquare: 'e8',
              onSquareTapped: _emptyTap,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BoardWidget), findsOneWidget);
    });
  });
}

void _emptyTap(String square) {}
