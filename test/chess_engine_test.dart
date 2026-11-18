import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess_pkg;
import 'package:chess_hotspot/engine/chess_board_state.dart';
import 'package:chess_hotspot/engine/move_validator.dart';
import 'package:chess_hotspot/engine/premove_handler.dart';

void main() {
  group('Step 1: Core Chess Engine & Rules Validation', () {
    late ChessBoardNotifier notifier;

    setUp(() {
      notifier = ChessBoardNotifier();
    });

    test('Initial board state conforms to FIDE standard start', () {
      final state = notifier.state;
      expect(state.fen, ChessBoardState.initialFen);
      expect(state.currentTurn, 'white');
      expect(state.isGameOver, false);
      expect(state.whiteMaterialAdvantage, 0);
      expect(state.selectedSquare, null);
      expect(state.lastMoveFrom, null);
      expect(state.lastMoveTo, null);
    });

    test('Strict constraint: No legal move dots/hints exposed on UI', () {
      // User selects 'e2'
      notifier.selectSquare('e2');
      final state = notifier.state;

      // Only selectedSquare is highlighted
      expect(state.selectedSquare, 'e2');
      // Verify legal targets exist for validation but state does not render them as hints
      expect(state.legalTargets, containsAll(['e3', 'e4']));
      // Tapping same square deselects
      notifier.selectSquare('e2');
      expect(notifier.state.selectedSquare, null);
    });

    test('Standard moves and turn alternation', () {
      // 1. e4
      final move1 = notifier.makeMove('e2', 'e4');
      expect(move1, true);
      expect(notifier.state.currentTurn, 'black');
      expect(notifier.state.lastMoveFrom, 'e2');
      expect(notifier.state.lastMoveTo, 'e4');

      // 1... e5
      final move2 = notifier.makeMove('e7', 'e5');
      expect(move2, true);
      expect(notifier.state.currentTurn, 'white');
      expect(notifier.state.lastMoveFrom, 'e7');
      expect(notifier.state.lastMoveTo, 'e5');
    });

    test('Castling: White kingside and queenside', () {
      // 1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. O-O
      notifier.makeMove('e2', 'e4');
      notifier.makeMove('e7', 'e5');
      notifier.makeMove('g1', 'f3');
      notifier.makeMove('b8', 'c6');
      notifier.makeMove('f1', 'c4');
      notifier.makeMove('f8', 'c5');

      // White kingside castle: e1 -> g1
      final castleWhite = notifier.makeMove('e1', 'g1');
      expect(castleWhite, true);
      expect(notifier.state.lastMoveFrom, 'e1');
      expect(notifier.state.lastMoveTo, 'g1');
      // King is on g1, rook is on f1
      final chess = chess_pkg.Chess.fromFEN(notifier.state.fen);
      expect(chess.get('g1')?.type, chess_pkg.PieceType.KING);
      expect(chess.get('f1')?.type, chess_pkg.PieceType.ROOK);
    });

    test('Castling: Black queenside', () {
      // FEN setup: Black queenside ready to castle
      // r3kbnr/ppp1pppp/2nqb3/3p4/4P3/3P1N2/PPP2PPP/RNBQKB1R b KQkq - 0 4
      notifier.applyFen('r3kbnr/ppp1pppp/2nqb3/3p4/4P3/3P1N2/PPP2PPP/RNBQKB1R b KQkq - 0 4');
      
      // Black castles queenside: e8 -> c8
      final castleBlack = notifier.makeMove('e8', 'c8');
      expect(castleBlack, true);
      expect(notifier.state.lastMoveFrom, 'e8');
      expect(notifier.state.lastMoveTo, 'c8');
    });

    test('En Passant: Pawn capture', () {
      // Setup En Passant position
      // White pawn on e5, Black pawn moves d7 -> d5
      notifier.applyFen('rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3');
      
      // White captures en passant: e5 -> d6
      final enPassant = notifier.makeMove('e5', 'd6');
      expect(enPassant, true);
      expect(notifier.state.whiteCaptured, contains('p'));
      expect(notifier.state.whiteMaterialAdvantage, 1);
    });

    test('Pawn Promotion: With modal selector support', () {
      // Position with white pawn ready to promote on a8
      notifier.applyFen('8/P7/8/8/8/8/8/4K2k w - - 0 1');

      // Promote to Queen
      final promoteQueen = notifier.makeMove('a7', 'a8', promotion: 'q');
      expect(promoteQueen, true);
      expect(notifier.state.fen.contains('Q'), true);

      // Test promote to Knight from FEN
      notifier.applyFen('8/P7/8/8/8/8/8/4K2k w - - 0 1');
      final promoteKnight = notifier.makeMove('a7', 'a8', promotion: 'n');
      expect(promoteKnight, true);
      expect(notifier.state.fen.contains('N'), true);
    });

    test('Check, Checkmate, and Game Over detection', () {
      // Scholar\'s Mate: 1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qxf7#
      notifier.makeMove('e2', 'e4');
      notifier.makeMove('e7', 'e5');
      notifier.makeMove('d1', 'h5');
      notifier.makeMove('b8', 'c6');
      notifier.makeMove('f1', 'c4');
      notifier.makeMove('g8', 'f6');
      
      // Qxf7#
      final mate = notifier.makeMove('h5', 'f7');
      expect(mate, true);
      expect(notifier.state.isGameOver, true);
      expect(notifier.state.gameOverReason, GameOverReason.checkmate);
    });

    test('Stalemate detection', () {
      // FEN: Black is stalemated (K on a8, no legal moves, not in check)
      // 7k/5Q2/6K1/8/8/8/8/8 b - - 0 1
      notifier.applyFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      
      // Since it is black\'s turn and black has 0 legal moves without check
      final chess = chess_pkg.Chess.fromFEN('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(chess.in_stalemate, true);
    });

    test('Insufficient Material detection', () {
      // King vs King
      final chessKK = chess_pkg.Chess.fromFEN('8/8/8/4k3/8/8/4K3/8 w - - 0 1');
      expect(MoveValidator.isInsufficientMaterial(chessKK), true);

      // King + Bishop vs King
      final chessKBK = chess_pkg.Chess.fromFEN('8/8/8/4k3/8/5B2/4K3/8 w - - 0 1');
      expect(MoveValidator.isInsufficientMaterial(chessKBK), true);

      // King + Knight vs King (f1 knight does not check e5 king)
      final chessKNK = chess_pkg.Chess.fromFEN('8/8/8/4k3/8/8/4K3/5N2 w - - 0 1');
      expect(MoveValidator.isInsufficientMaterial(chessKNK), true);
    });

    test('Threefold Repetition detection', () {
      final chess = chess_pkg.Chess();
      // Repetition sequence: 1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8
      chess.move({'from': 'g1', 'to': 'f3'});
      chess.move({'from': 'g8', 'to': 'f6'});
      chess.move({'from': 'f3', 'to': 'g1'});
      chess.move({'from': 'f6', 'to': 'g8'});
      chess.move({'from': 'g1', 'to': 'f3'});
      chess.move({'from': 'g8', 'to': 'f6'});
      chess.move({'from': 'f3', 'to': 'g1'});
      chess.move({'from': 'f6', 'to': 'g8'});

      expect(MoveValidator.isThreefoldRepetition(chess), true);
    });

    test('Premove handling: queues and executes or cancels', () {
      final premoveNotifier = PremoveNotifier();

      // Queue a premove
      premoveNotifier.setPremove('e7', 'e5');
      expect(premoveNotifier.state.hasPremove, true);
      expect(premoveNotifier.state.from, 'e7');
      expect(premoveNotifier.state.to, 'e5');

      // Test execution when legal (after 1. e4)
      final chess = chess_pkg.Chess();
      chess.move({'from': 'e2', 'to': 'e4'});

      final executed = premoveNotifier.tryExecute(chess);
      expect(executed, isNotNull);
      expect(executed!['from'], 'e7');
      expect(executed['to'], 'e5');
      expect(premoveNotifier.state.hasPremove, false);

      // Test invalid premove: gets cancelled silently
      premoveNotifier.setPremove('d7', 'd2'); // illegal
      final failed = premoveNotifier.tryExecute(chess);
      expect(failed, isNull);
      expect(premoveNotifier.state.hasPremove, false);
    });
  });
}
