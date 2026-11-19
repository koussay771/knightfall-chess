import 'package:chess/chess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'move_validator.dart';

// ---------------------------------------------------------------------------
// Enums & helpers
// ---------------------------------------------------------------------------

enum GameMode { standard, koth, dare }

enum GameOverReason {
  checkmate,
  stalemate,
  threefoldRepetition,
  insufficientMaterial,
  draw,
  resignation,
  timeout,
}

// Material values by piece type
const Map<String, int> _pieceValues = {
  'p': 1,
  'n': 3,
  'b': 3,
  'r': 5,
  'q': 9,
  'k': 0,
};

// ---------------------------------------------------------------------------
// ChessBoardState — immutable value object
// ---------------------------------------------------------------------------

class ChessBoardState {
  const ChessBoardState({
    required this.fen,
    this.selectedSquare,
    this.legalTargets = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.checkSquare,
    this.moveHistory = const [],
    this.whiteCaptured = const [],
    this.blackCaptured = const [],
    this.whiteMaterialAdvantage = 0,
    this.currentTurn = 'white',
    this.gameMode = GameMode.standard,
    this.isGameOver = false,
    this.gameOverReason,
    this.whiteTimeMs = 0,
    this.blackTimeMs = 0,
    this.winnerId,
  });

  /// The initial / starting FEN
  static const String initialFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  factory ChessBoardState.initial() => const ChessBoardState(
        fen: ChessBoardState.initialFen,
        currentTurn: 'white',
      );

  // Core game data
  final String fen;
  final String? selectedSquare;

  /// Legal targets for the selected square. Displayed subtly when a piece is active.
  final List<String> legalTargets;

  final String? lastMoveFrom;
  final String? lastMoveTo;

  /// Square of the King that is currently in check (null if no check)
  final String? checkSquare;

  final List<Map<String, dynamic>> moveHistory;

  /// Pieces captured by White (black pieces lost), symbols e.g. 'p','n','b'…
  final List<String> whiteCaptured;

  /// Pieces captured by Black (white pieces lost)
  final List<String> blackCaptured;

  /// Positive = white leads, negative = black leads
  final int whiteMaterialAdvantage;

  final String currentTurn; // 'white' | 'black'
  final GameMode gameMode;
  final bool isGameOver;
  final GameOverReason? gameOverReason;

  // Time state (kept here so toSyncMap can include it)
  final int whiteTimeMs;
  final int blackTimeMs;

  /// ID of the winning player (null for draws)
  final String? winnerId;

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  ChessBoardState copyWith({
    String? fen,
    Object? selectedSquare = _sentinel,
    List<String>? legalTargets,
    Object? lastMoveFrom = _sentinel,
    Object? lastMoveTo = _sentinel,
    Object? checkSquare = _sentinel,
    List<Map<String, dynamic>>? moveHistory,
    List<String>? whiteCaptured,
    List<String>? blackCaptured,
    int? whiteMaterialAdvantage,
    String? currentTurn,
    GameMode? gameMode,
    bool? isGameOver,
    Object? gameOverReason = _sentinel,
    int? whiteTimeMs,
    int? blackTimeMs,
    Object? winnerId = _sentinel,
  }) {
    return ChessBoardState(
      fen: fen ?? this.fen,
      selectedSquare: identical(selectedSquare, _sentinel)
          ? this.selectedSquare
          : selectedSquare as String?,
      legalTargets: legalTargets ?? this.legalTargets,
      lastMoveFrom: identical(lastMoveFrom, _sentinel)
          ? this.lastMoveFrom
          : lastMoveFrom as String?,
      lastMoveTo: identical(lastMoveTo, _sentinel)
          ? this.lastMoveTo
          : lastMoveTo as String?,
      checkSquare: identical(checkSquare, _sentinel)
          ? this.checkSquare
          : checkSquare as String?,
      moveHistory: moveHistory ?? this.moveHistory,
      whiteCaptured: whiteCaptured ?? this.whiteCaptured,
      blackCaptured: blackCaptured ?? this.blackCaptured,
      whiteMaterialAdvantage:
          whiteMaterialAdvantage ?? this.whiteMaterialAdvantage,
      currentTurn: currentTurn ?? this.currentTurn,
      gameMode: gameMode ?? this.gameMode,
      isGameOver: isGameOver ?? this.isGameOver,
      gameOverReason: identical(gameOverReason, _sentinel)
          ? this.gameOverReason
          : gameOverReason as GameOverReason?,
      whiteTimeMs: whiteTimeMs ?? this.whiteTimeMs,
      blackTimeMs: blackTimeMs ?? this.blackTimeMs,
      winnerId:
          identical(winnerId, _sentinel) ? this.winnerId : winnerId as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns net material advantage (white − black) using standard values.
  int getMaterialAdvantage() => whiteMaterialAdvantage;

  /// Returns captured pieces grouped by side.
  Map<String, List<String>> getCaptures() => {
        'white': List.unmodifiable(whiteCaptured),
        'black': List.unmodifiable(blackCaptured),
      };

  /// Map for the SYNC_STATE network packet.
  Map<String, dynamic> toSyncMap() => {
        'fen': fen,
        'moveHistory': moveHistory.map((m) => m['san'] as String).toList(),
        'whiteTimeMs': whiteTimeMs,
        'blackTimeMs': blackTimeMs,
      };
}

// Private sentinel so copyWith can distinguish "pass null" from "omit".
const Object _sentinel = Object();

// ---------------------------------------------------------------------------
// ChessBoardNotifier — StateNotifier
// ---------------------------------------------------------------------------

class ChessBoardNotifier extends StateNotifier<ChessBoardState> {
  ChessBoardNotifier() : super(ChessBoardState.initial());

  // Keep a live Chess instance in sync with state.fen
  Chess _chess = Chess();

  // -------------------------------------------------------------------------
  // selectSquare
  // -------------------------------------------------------------------------

  /// Select a square.  Legal targets are stored internally; they are NEVER
  /// exposed as UI dots — only the selected square highlight is used (per spec).
  ///
  /// Returns the list of legal target squares (for internal engine use only).
  List<String> selectSquare(String square) {
    if (state.isGameOver) return [];

    _chess = Chess.fromFEN(state.fen);

    // If we tap the same square again → deselect.
    if (state.selectedSquare == square) {
      state = state.copyWith(
        selectedSquare: null,
        legalTargets: [],
      );
      return [];
    }

    final piece = _chess.get(square);
    final turnColor = _chess.turn == Color.WHITE ? 'white' : 'black';

    // Only allow selecting own pieces on own turn.
    if (piece == null) {
      state = state.copyWith(selectedSquare: null, legalTargets: []);
      return [];
    }
    final pieceColor = piece.color == Color.WHITE ? 'white' : 'black';
    if (pieceColor != turnColor) {
      // Could be a premove — let the premove handler deal with it.
      state = state.copyWith(selectedSquare: null, legalTargets: []);
      return [];
    }

    final targets = MoveValidator.getMoves(_chess, square);
    state = state.copyWith(
      selectedSquare: square,
      legalTargets: targets,
    );
    return targets;
  }

  // -------------------------------------------------------------------------
  // makeMove
  // -------------------------------------------------------------------------

  /// Attempt to move a piece from [from] to [to].
  ///
  /// Returns `true` on success, `false` if the move is illegal.
  bool makeMove(String from, String to, {String? promotion}) {
    if (state.isGameOver) return false;

    _chess = Chess.fromFEN(state.fen);

    final effectiveTo = MoveValidator.normalizeMoveTo(from, to);

    // Build move map for chess package
    final moveMap = <String, String>{'from': from, 'to': effectiveTo};
    if (promotion != null) moveMap['promotion'] = promotion;

    // Check for capture before making the move
    final targetPiece = _chess.get(effectiveTo);
    final isEnPassant = _chess.get(from)?.type == PieceType.PAWN &&
        from[0] != effectiveTo[0] &&
        targetPiece == null;

    final moveResult = _chess.move(moveMap);
    if (moveResult == false) return false;

    // ---- Update captured pieces ----
    var newWhiteCaptured = List<String>.from(state.whiteCaptured);
    var newBlackCaptured = List<String>.from(state.blackCaptured);

    // The side that just moved is the PREVIOUS turn's color.
    final movedColor = state.currentTurn; // 'white' | 'black'

    if (targetPiece != null) {
      final sym = _pieceTypeToSymbol(targetPiece.type);
      if (movedColor == 'white') {
        newWhiteCaptured = [...newWhiteCaptured, sym];
      } else {
        newBlackCaptured = [...newBlackCaptured, sym];
      }
    } else if (isEnPassant) {
      if (movedColor == 'white') {
        newWhiteCaptured = [...newWhiteCaptured, 'p'];
      } else {
        newBlackCaptured = [...newBlackCaptured, 'p'];
      }
    }

    // ---- Material advantage ----
    final advantage = _computeAdvantage(newWhiteCaptured, newBlackCaptured);

    // ---- Move history (SAN) ----
    final sanList = MoveValidator.getSanHistory(_chess);
    final san = sanList.isNotEmpty ? sanList.last : '';
    final moveNum = (_chess.move_number).toInt();
    final newHistory = [
      ...state.moveHistory,
      {
        'san': san,
        'from': from,
        'to': effectiveTo,
        'promotion': promotion,
        'moveNumber': moveNum,
        'color': movedColor,
      }
    ];

    // ---- Turn ----
    final newTurn = _chess.turn == Color.WHITE ? 'white' : 'black';

    // ---- Check detection ----
    final checkSq = _chess.in_check ? MoveValidator.findKingSquare(_chess, newTurn) : null;

    // ---- Game over detection ----
    bool gameOver = false;
    GameOverReason? reason;

    if (_chess.in_checkmate) {
      gameOver = true;
      reason = GameOverReason.checkmate;
    } else if (_chess.in_stalemate) {
      gameOver = true;
      reason = GameOverReason.stalemate;
    } else if (MoveValidator.isThreefoldRepetition(_chess)) {
      gameOver = true;
      reason = GameOverReason.threefoldRepetition;
    } else if (MoveValidator.isInsufficientMaterial(_chess)) {
      gameOver = true;
      reason = GameOverReason.insufficientMaterial;
    } else if (_chess.in_draw) {
      gameOver = true;
      reason = GameOverReason.draw;
    }

    state = state.copyWith(
      fen: _chess.fen,
      selectedSquare: null,
      legalTargets: [],
      lastMoveFrom: from,
      lastMoveTo: effectiveTo,
      checkSquare: checkSq,
      moveHistory: newHistory,
      whiteCaptured: newWhiteCaptured,
      blackCaptured: newBlackCaptured,
      whiteMaterialAdvantage: advantage,
      currentTurn: newTurn,
      isGameOver: gameOver,
      gameOverReason: reason,
    );

    return true;
  }

  // -------------------------------------------------------------------------
  // applyFen
  // -------------------------------------------------------------------------

  /// Synchronise state from a FEN received over the network.
  void applyFen(String fen) {
    _chess = Chess.fromFEN(fen);
    final newTurn = _chess.turn == Color.WHITE ? 'white' : 'black';
    final checkSq = _chess.in_check ? MoveValidator.findKingSquare(_chess, newTurn) : null;
    state = state.copyWith(
      fen: fen,
      currentTurn: newTurn,
      checkSquare: checkSq,
      selectedSquare: null,
      legalTargets: [],
    );
  }

  // -------------------------------------------------------------------------
  // applySync
  // -------------------------------------------------------------------------

  /// Full sync from SYNC_STATE packet (called on reconnect / spectator join).
  void applySync({
    required String fen,
    required List<String> sanHistory,
    required int whiteTimeMs,
    required int blackTimeMs,
  }) {
    _chess = Chess.fromFEN(fen);
    final newTurn = _chess.turn == Color.WHITE ? 'white' : 'black';
    final checkSq = _chess.in_check ? MoveValidator.findKingSquare(_chess, newTurn) : null;

    final history = sanHistory
        .asMap()
        .entries
        .map((e) => <String, dynamic>{
              'san': e.value,
              'moveNumber': e.key ~/ 2 + 1,
              'color': e.key.isEven ? 'white' : 'black',
            })
        .toList();

    state = state.copyWith(
      fen: fen,
      currentTurn: newTurn,
      checkSquare: checkSq,
      moveHistory: history,
      whiteTimeMs: whiteTimeMs,
      blackTimeMs: blackTimeMs,
      selectedSquare: null,
      legalTargets: [],
    );
  }

  // -------------------------------------------------------------------------
  // Clock helpers
  // -------------------------------------------------------------------------

  void updateClocks({required int whiteTimeMs, required int blackTimeMs}) {
    state = state.copyWith(
      whiteTimeMs: whiteTimeMs,
      blackTimeMs: blackTimeMs,
    );
  }

  // -------------------------------------------------------------------------
  // Game-over helpers (called externally, e.g. resignation / timeout)
  // -------------------------------------------------------------------------

  void setGameOver(GameOverReason reason, {String? winnerId}) {
    state = state.copyWith(
      isGameOver: true,
      gameOverReason: reason,
      winnerId: winnerId,
    );
  }

  // -------------------------------------------------------------------------
  // Undo / Revert (Takeback)
  // -------------------------------------------------------------------------

  /// Undoes [count] plies from moveHistory by replaying from the starting FEN.
  /// Recomputes captured pieces, material advantage, checks, turn, and game state.
  /// Returns the reverted FEN, or null if history is empty.
  String? undoMoves([int count = 1]) {
    if (state.moveHistory.isEmpty || count <= 0) return null;
    final targetCount =
        (state.moveHistory.length - count).clamp(0, state.moveHistory.length);
    final historyToReplay = state.moveHistory.sublist(0, targetCount);

    _chess = Chess();
    var newWhiteCaptured = <String>[];
    var newBlackCaptured = <String>[];

    for (final m in historyToReplay) {
      final from = m['from'] as String? ?? '';
      final to = m['to'] as String? ?? '';
      final promo = m['promotion'] as String?;
      final targetPiece = _chess.get(to);
      final isEnPassant = _chess.get(from)?.type == PieceType.PAWN &&
          from.isNotEmpty &&
          to.isNotEmpty &&
          from[0] != to[0] &&
          targetPiece == null;
      final movedColor = _chess.turn == Color.WHITE ? 'white' : 'black';

      final moveMap = <String, String>{'from': from, 'to': to};
      if (promo != null) moveMap['promotion'] = promo;
      _chess.move(moveMap);

      if (targetPiece != null) {
        final sym = _pieceTypeToSymbol(targetPiece.type);
        if (movedColor == 'white') {
          newWhiteCaptured = [...newWhiteCaptured, sym];
        } else {
          newBlackCaptured = [...newBlackCaptured, sym];
        }
      } else if (isEnPassant) {
        if (movedColor == 'white') {
          newWhiteCaptured = [...newWhiteCaptured, 'p'];
        } else {
          newBlackCaptured = [...newBlackCaptured, 'p'];
        }
      }
    }

    final advantage = _computeAdvantage(newWhiteCaptured, newBlackCaptured);
    final newTurn = _chess.turn == Color.WHITE ? 'white' : 'black';
    final checkSq =
        _chess.in_check ? MoveValidator.findKingSquare(_chess, newTurn) : null;

    final lastMove = historyToReplay.isNotEmpty ? historyToReplay.last : null;

    state = state.copyWith(
      fen: _chess.fen,
      selectedSquare: null,
      legalTargets: [],
      lastMoveFrom: lastMove?['from'] as String?,
      lastMoveTo: lastMove?['to'] as String?,
      checkSquare: checkSq,
      moveHistory: historyToReplay,
      whiteCaptured: newWhiteCaptured,
      blackCaptured: newBlackCaptured,
      whiteMaterialAdvantage: advantage,
      currentTurn: newTurn,
      isGameOver: false,
      gameOverReason: null,
    );

    return _chess.fen;
  }

  // -------------------------------------------------------------------------
  // Reset
  // -------------------------------------------------------------------------

  void reset({GameMode mode = GameMode.standard}) {
    _chess = Chess();
    state = ChessBoardState.initial().copyWith(gameMode: mode);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  static int _computeAdvantage(
      List<String> whiteCaptured, List<String> blackCaptured) {
    final whiteScore =
        whiteCaptured.fold<int>(0, (s, p) => s + (_pieceValues[p] ?? 0));
    final blackScore =
        blackCaptured.fold<int>(0, (s, p) => s + (_pieceValues[p] ?? 0));
    return whiteScore - blackScore;
  }

  static String _pieceTypeToSymbol(PieceType type) {
    switch (type) {
      case PieceType.PAWN:
        return 'p';
      case PieceType.KNIGHT:
        return 'n';
      case PieceType.BISHOP:
        return 'b';
      case PieceType.ROOK:
        return 'r';
      case PieceType.QUEEN:
        return 'q';
      case PieceType.KING:
        return 'k';
      default:
        return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final chessBoardProvider =
    StateNotifierProvider<ChessBoardNotifier, ChessBoardState>(
  (ref) => ChessBoardNotifier(),
);
