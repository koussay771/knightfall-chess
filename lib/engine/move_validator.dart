import 'package:chess/chess.dart';

/// Static utility wrapper around the [Chess] engine for move validation,
/// check detection, SAN history extraction, special draw conditions,
/// and King square & check exposure resolution.
class MoveValidator {
  MoveValidator._();

  /// Normalizes target castling squares.
  /// If the player moves the King directly to the Rook's square (e.g. e1 -> h1),
  /// maps it to the standard FIDE castling destination (e1 -> g1).
  static String normalizeMoveTo(String from, String to) {
    if (from == 'e1' && to == 'h1') return 'g1';
    if (from == 'e1' && to == 'a1') return 'c1';
    if (from == 'e8' && to == 'h8') return 'g8';
    if (from == 'e8' && to == 'a8') return 'c8';
    return to;
  }

  /// Returns a list of legal target algebraic squares (e.g. `['e4', 'e3']`)
  /// for the piece currently located at [square].
  ///
  /// Includes Rook squares for Kingside/Queenside castling if castling is legal.
  static List<String> getMoves(Chess chess, String square) {
    try {
      final moves = chess.moves({
        'square': square,
        'verbose': true,
      });

      final targets = <String>[];
      for (final m in moves) {
        if (m is Map && m.containsKey('to')) {
          final to = m['to'] as String;
          if (!targets.contains(to)) {
            targets.add(to);
          }
        }
      }

      // If King can castle, also add the Rook squares so dragging or tapping
      // the Rook directly triggers Kingside or Queenside castling seamlessly
      if (square == 'e1') {
        if (targets.contains('g1') && !targets.contains('h1')) targets.add('h1');
        if (targets.contains('c1') && !targets.contains('a1')) targets.add('a1');
      } else if (square == 'e8') {
        if (targets.contains('g8') && !targets.contains('h8')) targets.add('h8');
        if (targets.contains('c8') && !targets.contains('a8')) targets.add('a8');
      }

      return targets;
    } catch (_) {
      return [];
    }
  }

  /// Returns whether the side to move is currently in check.
  static bool isInCheck(Chess chess) {
    return chess.in_check;
  }

  /// Finds the algebraic square where the King of [color] ('white' | 'black')
  /// is currently located.
  static String? findKingSquare(Chess chess, String color) {
    final kingChar = color == 'white' ? 'K' : 'k';
    final fenParts = chess.fen.split(' ');
    final rows = fenParts.first.split('/');
    for (var r = 0; r < 8 && r < rows.length; r++) {
      var col = 0;
      for (var i = 0; i < rows[r].length; i++) {
        final char = rows[r][i];
        final emptyCount = int.tryParse(char);
        if (emptyCount != null) {
          col += emptyCount;
        } else {
          if (char == kingChar) {
            final file = String.fromCharCode('a'.codeUnitAt(0) + col);
            final rank = (8 - r).toString();
            return '$file$rank';
          }
          col++;
        }
      }
    }
    return null;
  }

  /// Returns true if attempting [from]->[to] is blocked because the player's King
  /// is currently in check or the move would illegally expose the King to check.
  static bool wouldExposeOrLeaveInCheck(Chess chess, String from, String to) {
    if (isLegal(chess, from, to)) return false;

    // If currently in check, any illegal move fails to resolve the check
    if (chess.in_check) return true;

    // If not in check, verify if the moving piece belongs to active player
    final piece = chess.get(from);
    if (piece == null) return false;
    final turnColor = chess.turn;
    if (piece.color != turnColor) return false;

    return true;
  }

  /// Validates whether moving from [from] to [to] (with optional [promotion]
  /// piece 'q', 'r', 'b', 'n') is a legal move in the current board state.
  static bool isLegal(
    Chess chess,
    String from,
    String to, {
    String? promotion,
  }) {
    final effectiveTo = normalizeMoveTo(from, to);
    try {
      final moves = chess.moves({
        'square': from,
        'verbose': true,
      });

      for (final m in moves) {
        if (m is Map && m['from'] == from && m['to'] == effectiveTo) {
          if (promotion != null && m['promotion'] != null) {
            if (m['promotion'].toString().toLowerCase() ==
                promotion.toLowerCase()) {
              return true;
            }
          } else {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns the move history in Standard Algebraic Notation (SAN),
  /// e.g. `['e4', 'e5', 'Nf3', 'Nc6']`.
  static List<String> getSanHistory(Chess chess) {
    try {
      final history = chess.getHistory();
      return history.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns true if the position has insufficient material for checkmate
  /// (e.g. King vs King, King+Bishop vs King, King+Knight vs King).
  static bool isInsufficientMaterial(Chess chess) {
    try {
      return chess.insufficient_material;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the current position has occurred 3 times (threefold repetition).
  static bool isThreefoldRepetition(Chess chess) {
    try {
      return chess.in_threefold_repetition;
    } catch (_) {
      return false;
    }
  }
}
