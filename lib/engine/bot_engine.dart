import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:chess/chess.dart' as chess_lib;

/// Top-level worker function executed on a background Isolate via [compute].
Map<String, String>? _computeBestMoveWorker(Map<String, dynamic> params) {
  final fen = params['fen'] as String;
  final depth = (params['depth'] as int?) ?? 3;
  return ChessBot.computeBestMoveSync(fen, depth);
}

/// Offline Chess Bot rated ~1500 ELO.
///
/// Features:
/// - Minimax search with Alpha-Beta pruning (depth 3-4).
/// - Non-blocking background isolate evaluation via Flutter's [compute].
/// - Move ordering (MVV-LVA for captures, checks, promotions).
/// - Comprehensive piece-square positional evaluation (PST).
/// - Opening repertoire for natural book play.
/// - Realistic thinking delay (500ms - 900ms) that never freezes the UI or timers.
class ChessBot {
  final int searchDepth;
  final Random _rng = Random();

  ChessBot({this.searchDepth = 3});

  /// Evaluates the current [fen] position on a background isolate and returns the best move as
  /// `{'from': 'e2', 'to': 'e4', 'promotion': 'q'}`.
  ///
  /// Returns `null` if the game is over or no legal moves exist.
  Future<Map<String, String>?> findBestMove(String fen) async {
    final chess = chess_lib.Chess.fromFEN(fen);
    if (chess.in_checkmate || chess.in_draw) return null;

    final legalMoves = chess.moves({'verbose': true});
    if (legalMoves.isEmpty) return null;

    // Check opening book for standard start position
    const initialFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    if (fen == initialFen || (chess.history.isNotEmpty && chess.history.length <= 2)) {
      final bookMove = _getOpeningBookMove(chess, legalMoves, _rng);
      if (bookMove != null) {
        // Add realistic human think time asynchronously
        await Future.delayed(
            Duration(milliseconds: 300 + _rng.nextInt(200)));
        return bookMove;
      }
    }

    final stopwatch = Stopwatch()..start();

    // Offload Minimax / Alpha-Beta calculation to a background Isolate
    // so the UI frame rate (60fps) and game clocks never freeze.
    final bestMove = await compute(_computeBestMoveWorker, {
      'fen': fen,
      'depth': searchDepth,
    });

    // Ensure human thinking delay without blocking the UI thread
    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 500) {
      await Future.delayed(Duration(milliseconds: 500 - elapsed));
    }

    return bestMove;
  }

  /// Synchronous core calculation meant to run inside a worker Isolate.
  static Map<String, String>? computeBestMoveSync(String fen, int depth) {
    final chess = chess_lib.Chess.fromFEN(fen);
    if (chess.in_checkmate || chess.in_draw) return null;

    final legalMoves = chess.moves({'verbose': true});
    if (legalMoves.isEmpty) return null;

    final rng = Random();
    final isWhite = chess.turn == chess_lib.Color.WHITE;
    final sortedMoves = _orderMoves(chess, legalMoves);

    Map<String, String>? bestMove;
    int bestScore = isWhite ? -999999 : 999999;
    int alpha = -999999;
    int beta = 999999;

    for (final move in sortedMoves) {
      final moveMap = <String, String>{
        'from': move['from'] as String,
        'to': move['to'] as String,
      };
      if (move['promotion'] != null) {
        moveMap['promotion'] = move['promotion'] as String;
      }

      final testChess = chess_lib.Chess.fromFEN(fen);
      final executed = testChess.move(moveMap);
      if (executed == false) continue;

      // If this move delivers checkmate, pick it immediately
      if (testChess.in_checkmate) {
        return moveMap;
      }

      final score = _alphaBeta(
        testChess,
        depth - 1,
        alpha,
        beta,
        !isWhite,
      );

      // Add a slight ±8 centipawn jitter for realistic 1500 ELO human variability
      final jitteredScore = score + (rng.nextInt(17) - 8);

      if (isWhite) {
        if (jitteredScore > bestScore || bestMove == null) {
          bestScore = jitteredScore;
          bestMove = moveMap;
        }
        alpha = max(alpha, bestScore);
      } else {
        if (jitteredScore < bestScore || bestMove == null) {
          bestScore = jitteredScore;
          bestMove = moveMap;
        }
        beta = min(beta, bestScore);
      }

      if (beta <= alpha) break;
    }

    return bestMove;
  }

  static int _alphaBeta(
    chess_lib.Chess chess,
    int depth,
    int alpha,
    int beta,
    bool isMaximizing,
  ) {
    if (chess.in_checkmate) {
      // Return high mate score penalized by distance to mate
      return isMaximizing ? -200000 - depth : 200000 + depth;
    }
    if (chess.in_draw) return 0;

    if (depth <= 0) {
      return _evaluatePosition(chess);
    }

    final moves = chess.moves({'verbose': true});
    if (moves.isEmpty) return _evaluatePosition(chess);

    final orderedMoves = _orderMoves(chess, moves);

    if (isMaximizing) {
      int maxScore = -999999;
      for (final m in orderedMoves) {
        final moveMap = <String, String>{
          'from': m['from'] as String,
          'to': m['to'] as String,
        };
        if (m['promotion'] != null) {
          moveMap['promotion'] = m['promotion'] as String;
        }

        final clone = chess_lib.Chess.fromFEN(chess.fen);
        if (clone.move(moveMap) == false) continue;

        final score = _alphaBeta(clone, depth - 1, alpha, beta, false);
        maxScore = max(maxScore, score);
        alpha = max(alpha, maxScore);
        if (beta <= alpha) break; // Beta cutoff
      }
      return maxScore;
    } else {
      int minScore = 999999;
      for (final m in orderedMoves) {
        final moveMap = <String, String>{
          'from': m['from'] as String,
          'to': m['to'] as String,
        };
        if (m['promotion'] != null) {
          moveMap['promotion'] = m['promotion'] as String;
        }

        final clone = chess_lib.Chess.fromFEN(chess.fen);
        if (clone.move(moveMap) == false) continue;

        final score = _alphaBeta(clone, depth - 1, alpha, beta, true);
        minScore = min(minScore, score);
        beta = min(beta, minScore);
        if (beta <= alpha) break; // Alpha cutoff
      }
      return minScore;
    }
  }

  /// Evaluates static board position from White's perspective in centipawns.
  /// Positive = White advantage, Negative = Black advantage.
  static int _evaluatePosition(chess_lib.Chess chess) {
    if (chess.in_checkmate) {
      return chess.turn == chess_lib.Color.WHITE ? -200000 : 200000;
    }
    if (chess.in_draw) return 0;

    int totalScore = 0;
    final placement = chess.fen.split(' ').first;
    final rows = placement.split('/');

    for (var r = 0; r < 8 && r < rows.length; r++) {
      final rowStr = rows[r];
      var c = 0;
      for (var i = 0; i < rowStr.length; i++) {
        final char = rowStr[i];
        final emptyCount = int.tryParse(char);
        if (emptyCount != null) {
          c += emptyCount;
        } else {
          if (c < 8) {
            totalScore += _getPieceSquareScore(char, r, c);
            c++;
          }
        }
      }
    }

    // Mobility bonus (+2 centipawns per legal move available)
    try {
      final currentMoves = chess.moves().length;
      final mobilityBonus = currentMoves * 2;
      totalScore +=
          chess.turn == chess_lib.Color.WHITE ? mobilityBonus : -mobilityBonus;
    } catch (_) {}

    return totalScore;
  }

  static int _getPieceSquareScore(String piece, int row, int col) {
    final isWhite = piece == piece.toUpperCase();
    final lower = piece.toLowerCase();

    // Map row according to color (PSTs defined from White's perspective: row 0 = rank 8)
    final tableRow = isWhite ? row : 7 - row;
    final tableCol = col;
    final index = tableRow * 8 + tableCol;

    int baseMaterial = 0;
    int positionalBonus = 0;

    switch (lower) {
      case 'p':
        baseMaterial = 100;
        positionalBonus = _pawnTable[index];
        break;
      case 'n':
        baseMaterial = 320;
        positionalBonus = _knightTable[index];
        break;
      case 'b':
        baseMaterial = 330;
        positionalBonus = _bishopTable[index];
        break;
      case 'r':
        baseMaterial = 500;
        positionalBonus = _rookTable[index];
        break;
      case 'q':
        baseMaterial = 900;
        positionalBonus = _queenTable[index];
        break;
      case 'k':
        baseMaterial = 20000;
        positionalBonus = _kingTable[index];
        break;
    }

    final total = baseMaterial + positionalBonus;
    return isWhite ? total : -total;
  }

  /// Sorts moves for optimal Alpha-Beta pruning (MVV-LVA for captures).
  static List<dynamic> _orderMoves(chess_lib.Chess chess, List<dynamic> moves) {
    final scored = moves.map((m) {
      int score = 0;
      // Promotion
      if (m['promotion'] != null) {
        score += 800;
      }
      // Captures (MVV-LVA)
      if (m['captured'] != null) {
        final victimVal = _pieceBaseValue(m['captured'].toString());
        final attackerVal = _pieceBaseValue(m['piece'].toString());
        score += 10000 + (victimVal * 10 - attackerVal);
      }
      // Checks
      if (m['san'] != null && (m['san'] as String).contains('+')) {
        score += 500;
      }
      return {'move': m, 'score': score};
    }).toList();

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scored.map((e) => e['move']).toList();
  }

  static int _pieceBaseValue(String p) {
    final lower = p.toLowerCase();
    if (lower.contains('q')) return 900;
    if (lower.contains('r')) return 500;
    if (lower.contains('b')) return 330;
    if (lower.contains('n')) return 320;
    if (lower.contains('p')) return 100;
    if (lower.contains('k')) return 20000;
    return 0;
  }

  static Map<String, String>? _getOpeningBookMove(
      chess_lib.Chess chess, List<dynamic> moves, Random rng) {
    final history = chess.history;

    if (history.isEmpty) {
      // First move as White: 1. e4 (60%) or 1. d4 (35%) or 1. Nf3 (5%)
      final r = rng.nextInt(100);
      if (r < 60) return {'from': 'e2', 'to': 'e4'};
      if (r < 95) return {'from': 'd2', 'to': 'd4'};
      return {'from': 'g1', 'to': 'f3'};
    }

    if (history.length == 1) {
      // First move as Black
      final firstMove = history.first.move;
      final whiteSan = chess.history.isNotEmpty ? firstMove.from + firstMove.to : '';

      if (whiteSan == 'e2e4') {
        // Responses to e4: 1... c5 (Sicilian) or 1... e5 (Open Game)
        return rng.nextBool()
            ? {'from': 'c7', 'to': 'c5'}
            : {'from': 'e7', 'to': 'e5'};
      }
      if (whiteSan == 'd2d4') {
        // Responses to d4: 1... Nf6 (Indian) or 1... d5
        return rng.nextBool()
            ? {'from': 'g8', 'to': 'f6'}
            : {'from': 'd7', 'to': 'd5'};
      }
    }

    return null;
  }

  // ─── Positional Piece-Square Tables (PeSTO-derived) ────────────────────────

  static const List<int> _pawnTable = [
    0, 0, 0, 0, 0, 0, 0, 0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0
  ];

  static const List<int> _knightTable = [
    -50, -40, -30, -30, -30, -30, -40, -50,
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50
  ];

  static const List<int> _bishopTable = [
    -20, -10, -10, -10, -10, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20
  ];

  static const List<int> _rookTable = [
    0, 0, 0, 0, 0, 0, 0, 0,
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0
  ];

  static const List<int> _queenTable = [
    -20, -10, -10, -5, -5, -10, -10, -20,
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20
  ];

  static const List<int> _kingTable = [
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20
  ];
}
