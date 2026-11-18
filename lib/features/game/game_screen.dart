import 'dart:async';
import 'package:chess/chess.dart' as chess_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/theme_constants.dart';
import '../../core/models/match_record.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/database_helper.dart';
import '../../core/utils/sound_manager.dart';
import '../../engine/bot_engine.dart';
import '../../engine/chess_board_state.dart';
import '../../engine/move_validator.dart';
import '../../engine/premove_handler.dart';
import '../../network/sync_protocol.dart';
import '../../network/tcp_client.dart';
import '../../network/tcp_server.dart';
import 'board_widget.dart';
import 'clock_widget.dart';
import 'move_history_widget.dart';
import 'takeback_dialog.dart';

class GameScreen extends ConsumerStatefulWidget {
  final bool isHost;
  final String myPlayerId;
  final String myPlayerName;
  final String opponentName;
  final String myColor; // 'white' | 'black'
  final int initialTimeSeconds; // 0 = unlimited
  final int incrementSeconds;
  final String gameMode; // 'standard' | 'koth' | 'dare'
  final String? dareText;
  final bool isBot;

  const GameScreen({
    super.key,
    required this.isHost,
    required this.myPlayerId,
    required this.myPlayerName,
    this.opponentName = 'Opponent',
    required this.myColor,
    this.initialTimeSeconds = 300,
    this.incrementSeconds = 0,
    this.gameMode = 'standard',
    this.dareText,
    this.isBot = false,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _clockTimer;
  late int _whiteTimeMs;
  late int _blackTimeMs;
  bool _takebackPending = false;
  bool _gameOverHandled = false;
  int _shakeTrigger = 0;
  String? _flashKingSquare;

  @override
  void initState() {
    super.initState();
    _whiteTimeMs = widget.initialTimeSeconds * 1000;
    _blackTimeMs = widget.initialTimeSeconds * 1000;

    // Reset engine board to initial standard state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chessBoardProvider.notifier).reset(
            mode: widget.gameMode == 'koth'
                ? GameMode.koth
                : widget.gameMode == 'dare'
                    ? GameMode.dare
                    : GameMode.standard,
          );
      ref.read(premoveProvider.notifier).clearPremove();
      if (!widget.isBot) {
        _setupNetworkListeners();
      }
      _startClockTimer();

      if (widget.isBot && widget.myColor == 'black') {
        _triggerBotMove();
      }
    });
  }

  bool _botThinking = false;
  final ChessBot _bot = ChessBot(searchDepth: 3);

  Future<void> _triggerBotMove() async {
    if (_botThinking || !mounted) return;
    _botThinking = true;

    final board = ref.read(chessBoardProvider);
    if (board.isGameOver) {
      _botThinking = false;
      return;
    }

    final move = await _bot.findBestMove(board.fen);
    _botThinking = false;

    if (move != null && mounted) {
      final notifier = ref.read(chessBoardProvider.notifier);
      final from = move['from']!;
      final to = move['to']!;
      final promo = move['promotion'];

      final success = notifier.makeMove(from, to, promotion: promo);
      if (success) {
        SoundManager.instance.playMove();

        final updated = ref.read(chessBoardProvider);
        if (updated.isGameOver) {
          _handleGameEndedLocally(updated);
        } else {
          _checkPremoveTrigger();
        }
      }
    }
  }

  void _setupNetworkListeners() {
    if (widget.isHost) {
      final server = ref.read(tcpServerProvider.notifier);
      server.onMessageReceived = (pid, msg) => _handleIncomingMessage(msg);
      server.buildSyncState = () {
        final board = ref.read(chessBoardProvider);
        return SyncProtocol.syncState(
          fen: board.fen,
          moveHistory:
              board.moveHistory.map((m) => m['san'] as String).toList(),
          whiteTimeMs: _whiteTimeMs,
          blackTimeMs: _blackTimeMs,
        );
      };
    } else {
      final client = ref.read(tcpClientProvider.notifier);
      client.onMessageReceived = (msg) => _handleIncomingMessage(msg);
    }
  }

  void _startClockTimer() {
    if (widget.initialTimeSeconds <= 0) return; // Unlimited

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final board = ref.read(chessBoardProvider);
      if (board.isGameOver) {
        _clockTimer?.cancel();
        return;
      }

      setState(() {
        if (board.currentTurn == 'white') {
          _whiteTimeMs = (_whiteTimeMs - 100).clamp(0, 99999999);
          if (_whiteTimeMs <= 0 && !_gameOverHandled) {
            _onTimeout('white');
          }
        } else {
          _blackTimeMs = (_blackTimeMs - 100).clamp(0, 99999999);
          if (_blackTimeMs <= 0 && !_gameOverHandled) {
            _onTimeout('black');
          }
        }
      });
    });
  }

  void _onTimeout(String timedOutColor) {
    _gameOverHandled = true;
    _clockTimer?.cancel();
    final winnerId = timedOutColor == widget.myColor ? null : widget.myPlayerId;
    ref.read(chessBoardProvider.notifier).setGameOver(
          GameOverReason.timeout,
          winnerId: winnerId,
        );

    final msg = SyncProtocol.gameOver(
      reason: 'timeout',
      winnerId: winnerId,
    );
    _sendNetworkMessage(msg);
    _showGameOverDialog('Timeout', winnerId == widget.myPlayerId ? 'You won on time!' : 'Time ran out!');
  }

  // ─── Network Message Dispatch ─────────────────────────────────────────────

  void _handleIncomingMessage(Map<String, dynamic> msg) {
    final type = SyncProtocol.normalizeType(msg['type'] as String?);

    if (type == SyncProtocol.typeMove) {
      final from = msg['from'] as String;
      final to = msg['to'] as String;
      final promotion = msg['promotion'] as String?;
      final fen = msg['fen'] as String?;
      final whiteMs = msg['whiteTimeMs'] as int?;
      final blackMs = msg['blackTimeMs'] as int?;

      if (whiteMs != null) _whiteTimeMs = whiteMs;
      if (blackMs != null) _blackTimeMs = blackMs;

      // Apply opponent move to board
      final notifier = ref.read(chessBoardProvider.notifier);
      final moveSuccess = notifier.makeMove(from, to, promotion: promotion);
      if (!moveSuccess && fen != null) {
        notifier.applyFen(fen);
      }

      SoundManager.instance.playMove();

      // Check for premove trigger
      _checkPremoveTrigger();
    } else if (type == SyncProtocol.typeTakebackReq) {
      _showIncomingTakebackRequest();
    } else if (type == SyncProtocol.typeTakebackRes) {
      final accepted = msg['accepted'] as bool? ?? false;
      final revertedFen = msg['revertedFen'] as String?;

      if (accepted && revertedFen != null) {
        ref.read(chessBoardProvider.notifier).applyFen(revertedFen);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takeback accepted!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takeback declined.')),
        );
      }
    } else if (type == SyncProtocol.typeGameOver) {
      final reason = msg['reason'] as String? ?? 'resignation';
      final winnerId = msg['winnerId'] as String?;
      _handleGameOverReceived(reason, winnerId);
    } else if (type == SyncProtocol.typeSyncState) {
      final fen = msg['fen'] as String;
      final history = List<String>.from(msg['moveHistory'] as List? ?? []);
      final wMs = msg['whiteTimeMs'] as int? ?? _whiteTimeMs;
      final bMs = msg['blackTimeMs'] as int? ?? _blackTimeMs;

      _whiteTimeMs = wMs;
      _blackTimeMs = bMs;

      ref.read(chessBoardProvider.notifier).applySync(
            fen: fen,
            sanHistory: history,
            whiteTimeMs: wMs,
            blackTimeMs: bMs,
          );
    }
  }

  void _sendNetworkMessage(String payload) {
    if (widget.isHost) {
      ref.read(tcpServerProvider.notifier).broadcast(payload);
    } else {
      ref.read(tcpClientProvider.notifier).send(payload);
    }
  }

  // ─── Square Tap & Move Handling ───────────────────────────────────────────

  Future<void> _handleSquareTapped(String square) async {
    final board = ref.read(chessBoardProvider);
    if (board.isGameOver) return;

    final isMyTurn = board.currentTurn == widget.myColor;

    if (isMyTurn) {
      final selected = board.selectedSquare;

      if (selected == null) {
        // First tap: select piece
        ref.read(chessBoardProvider.notifier).selectSquare(square);
      } else if (selected == square) {
        // Tap same: deselect
        ref.read(chessBoardProvider.notifier).selectSquare(square);
      } else {
        // Attempt to move from selected -> square
        await _attemptPlayerMove(selected, square);
      }
    } else {
      // Opponent's turn: Premove handler
      _handlePremoveTap(square);
    }
  }

  Future<void> _attemptPlayerMove(String from, String to,
      {String? promoOverride}) async {
    final board = ref.read(chessBoardProvider);
    final isPawn = _isPawn(board.fen, from);
    final isPromotion = isPawn && (to.endsWith('8') || to.endsWith('1'));

    String? promoPiece = promoOverride;
    if (isPromotion && promoPiece == null) {
      promoPiece = await _showPromotionModal(widget.myColor == 'white');
      if (promoPiece == null) {
        // User cancelled promotion
        return;
      }
    }

    final notifier = ref.read(chessBoardProvider.notifier);
    final success = notifier.makeMove(from, to, promotion: promoPiece);

    if (success) {
      // Add increment
      if (widget.myColor == 'white') {
        _whiteTimeMs += widget.incrementSeconds * 1000;
      } else {
        _blackTimeMs += widget.incrementSeconds * 1000;
      }

      SoundManager.instance.playMove();

      final updatedBoard = ref.read(chessBoardProvider);

      if (!widget.isBot) {
        // Transmit MOVE packet
        final movePacket = SyncProtocol.move(
          from: from,
          to: to,
          promotion: promoPiece,
          fen: updatedBoard.fen,
          whiteTimeMs: _whiteTimeMs,
          blackTimeMs: _blackTimeMs,
        );
        _sendNetworkMessage(movePacket);
      } else {
        if (!updatedBoard.isGameOver) {
          _triggerBotMove();
        }
      }

      // Check if game over
      if (updatedBoard.isGameOver) {
        _handleGameEndedLocally(updatedBoard);
      }
    } else {
      // Check if this move was blocked due to check or check exposure
      final chess = chess_pkg.Chess.fromFEN(board.fen);
      final isExposure =
          MoveValidator.wouldExposeOrLeaveInCheck(chess, from, to);

      if (isExposure) {
        // Block move, play alert sound effect, shake board, and re-highlight King
        SoundManager.instance.playIllegalMove();
        final kingSq = MoveValidator.findKingSquare(chess, widget.myColor);
        setState(() {
          _shakeTrigger++;
          _flashKingSquare = kingSq;
        });

        Timer(const Duration(milliseconds: 1400), () {
          if (mounted) {
            setState(() {
              _flashKingSquare = null;
            });
          }
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chess.in_check
                  ? 'Invalid move: You must protect or escape check!'
                  : 'Illegal move: King cannot be exposed to check!',
            ),
            backgroundColor: const Color(0xFFE53935),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // If moving failed, check if user tapped another of their own pieces
        notifier.selectSquare(to);
      }
    }
  }

  Future<void> _handlePieceDropped(String from, String to) async {
    final board = ref.read(chessBoardProvider);
    if (board.isGameOver) return;

    final isMyTurn = board.currentTurn == widget.myColor;
    if (isMyTurn) {
      await _attemptPlayerMove(from, to);
    } else {
      // Premove drag and drop
      ref.read(premoveProvider.notifier).setPremove(from, to);
      SoundManager.instance.playMove();
    }
  }

  // ─── Premove Handling ─────────────────────────────────────────────────────

  String? _premoveStartSquare;

  void _handlePremoveTap(String square) {
    if (_premoveStartSquare == null) {
      _premoveStartSquare = square;
      ref.read(premoveProvider.notifier).setPremove(square, square);
    } else {
      final from = _premoveStartSquare!;
      _premoveStartSquare = null;

      if (from == square) {
        ref.read(premoveProvider.notifier).clearPremove();
      } else {
        ref.read(premoveProvider.notifier).setPremove(from, square);
      }
    }
  }

  void _checkPremoveTrigger() {
    final premoveState = ref.read(premoveProvider);
    if (!premoveState.hasPremove) return;

    final board = ref.read(chessBoardProvider);
    if (board.currentTurn != widget.myColor) return;

    final from = premoveState.from!;
    final to = premoveState.to!;

    // Auto promote to Queen on premove
    final isPawn = _isPawn(board.fen, from);
    final promo = isPawn && (to.endsWith('8') || to.endsWith('1')) ? 'q' : null;

    ref.read(premoveProvider.notifier).clearPremove();
    _attemptPlayerMove(from, to, promoOverride: promo);
  }

  // ─── Takeback Request ─────────────────────────────────────────────────────

  void _sendTakebackRequest() {
    if (_takebackPending) return;
    _takebackPending = true;

    final msg = SyncProtocol.takebackReq(requesterId: widget.myPlayerId);
    _sendNetworkMessage(msg);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Takeback requested... waiting for opponent response'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showIncomingTakebackRequest() {
    TakebackDialog.show(
      context,
      requesterName: widget.opponentName,
    ).then((accepted) {
      final isAccepted = accepted ?? false;
      final board = ref.read(chessBoardProvider);

      String? revertedFen;
      if (isAccepted) {
        // Revert 1 or 2 moves (to previous player position)
        // For simplicity, apply previous FEN or send current
        revertedFen = board.fen;
      }

      final res = SyncProtocol.takebackRes(
        accepted: isAccepted,
        revertedFen: revertedFen,
      );
      _sendNetworkMessage(res);
    });
  }

  // ─── Promotion Modal ──────────────────────────────────────────────────────

  Future<String?> _showPromotionModal(bool isWhite) {
    final pieces = [
      {'label': 'Queen', 'code': 'q', 'symbol': isWhite ? '♕' : '♛'},
      {'label': 'Rook', 'code': 'r', 'symbol': isWhite ? '♖' : '♜'},
      {'label': 'Bishop', 'code': 'b', 'symbol': isWhite ? '♗' : '♝'},
      {'label': 'Knight', 'code': 'n', 'symbol': isWhite ? '♘' : '♞'},
    ];

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Select Promotion Piece',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 16),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: pieces.map((p) {
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(ctx).pop(p['code'] as String),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF313244),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p['symbol'] as String,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Game Over Flow ───────────────────────────────────────────────────────

  void _handleGameEndedLocally(ChessBoardState board) {
    _clockTimer?.cancel();
    _gameOverHandled = true;

    final reasonStr = board.gameOverReason.toString().split('.').last;
    final winnerId =
        board.gameOverReason == GameOverReason.checkmate ? widget.myPlayerId : null;

    final msg = SyncProtocol.gameOver(reason: reasonStr, winnerId: winnerId);
    _sendNetworkMessage(msg);

    _saveMatchToHistory(
      result: winnerId == widget.myPlayerId ? 'win' : 'draw',
      reason: reasonStr,
    );

    _showGameOverDialog(
      'Game Over',
      winnerId == widget.myPlayerId
          ? 'Checkmate! You won!'
          : 'Game ended by $reasonStr',
    );
  }

  void _handleGameOverReceived(String reason, String? winnerId) {
    _clockTimer?.cancel();
    _gameOverHandled = true;

    final isWin = winnerId == widget.myPlayerId;
    final isLoss = winnerId != null && !isWin;

    _saveMatchToHistory(
      result: isWin ? 'win' : (isLoss ? 'loss' : 'draw'),
      reason: reason,
    );

    _showGameOverDialog(
      'Game Over',
      isWin
          ? 'Victory!'
          : (isLoss ? '${widget.opponentName} won by $reason' : 'Draw ($reason)'),
    );
  }

  Future<void> _saveMatchToHistory({
    required String result,
    required String reason,
  }) async {
    final board = ref.read(chessBoardProvider);
    final record = MatchRecord(
      id: const Uuid().v4(),
      date: DateTime.now(),
      opponentName: widget.opponentName,
      result: result,
      reason: reason,
      mode: widget.gameMode,
      dareText: widget.dareText,
      moves: board.moveHistory.map((m) => m['san'] as String).toList(),
      pgn: board.moveHistory.map((m) => m['san']).join(' '),
      myMaterialAdvantage: board.whiteMaterialAdvantage,
    );

    try {
      await DatabaseHelper.instance.insertMatch(record);
    } catch (_) {}
  }

  void _showGameOverDialog(String title, String subtitle) {
    SoundManager.instance.playGameOver();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFCDD6F4),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFA6ADC8), fontSize: 16),
            ),
            if (widget.dareText != null && widget.dareText!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9E2AF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF9E2AF)),
                ),
                child: Text(
                  'Dare: ${widget.dareText}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF9E2AF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF769656),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Return to Lobby'),
            ),
          ),
        ],
      ),
    );
  }

  bool _isPawn(String fen, String square) {
    final col = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final row = 8 - int.parse(square[1]);
    final placement = fen.split(' ').first;
    final rows = placement.split('/');
    if (row < 0 || row >= rows.length) return false;

    var c = 0;
    for (var i = 0; i < rows[row].length; i++) {
      final char = rows[row][i];
      final empty = int.tryParse(char);
      if (empty != null) {
        c += empty;
      } else {
        if (c == col) return char.toLowerCase() == 'p';
        c++;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(chessBoardProvider);
    final premove = ref.watch(premoveProvider);
    final themeId = ref.watch(boardThemeProvider);
    final themeColors = AppThemes.boardThemes[themeId] ?? AppThemes.boardThemes['tournament_green']!;
    final isFlipped = widget.myColor == 'black';

    final isWhiteTurn = board.currentTurn == 'white';
    final isMyTurn = board.currentTurn == widget.myColor;

    final opponentTimeMs = isFlipped ? _whiteTimeMs : _blackTimeMs;
    final myTimeMs = isFlipped ? _blackTimeMs : _whiteTimeMs;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        title: Text(
          widget.gameMode == 'dare'
              ? 'Dare Match'
              : (widget.gameMode == 'koth' ? 'King of the Hill' : 'Chess Match'),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag, color: Color(0xFFF38BA8)),
            tooltip: 'Resign',
            onPressed: () {
              final msg = SyncProtocol.gameOver(
                reason: 'resignation',
                winnerId: widget.opponentName,
              );
              _sendNetworkMessage(msg);
              _handleGameOverReceived('resignation', widget.opponentName);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Dare Banner if present
              if (widget.dareText != null && widget.dareText!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9E2AF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF9E2AF)),
                  ),
                  child: Text(
                    '⚡ Dare: ${widget.dareText}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF9E2AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

              // Top row: Opponent Clock & info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClockWidget(
                    timeMs: opponentTimeMs,
                    isActive: isFlipped ? isWhiteTurn : !isWhiteTurn,
                    isUnlimited: widget.initialTimeSeconds <= 0,
                    playerName: widget.opponentName,
                    isWhite: !isFlipped,
                  ),
                  if (!isMyTurn)
                    const Chip(
                      label: Text('Opponent Turn', style: TextStyle(fontSize: 11)),
                      backgroundColor: Color(0xFF313244),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Interactive 8x8 Chess Board with smooth drag-and-drop & legal paths
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: BoardWidget(
                      fen: board.fen,
                      selectedSquare: board.selectedSquare,
                      legalTargets: board.legalTargets,
                      lastMoveFrom: board.lastMoveFrom,
                      lastMoveTo: board.lastMoveTo,
                      premoveFrom: premove.from,
                      premoveTo: premove.to,
                      checkSquare: _flashKingSquare ?? board.checkSquare,
                      flipped: isFlipped,
                      lightSquareColor: themeColors[0],
                      darkSquareColor: themeColors[1],
                      shakeTrigger: _shakeTrigger,
                      onSquareTapped: _handleSquareTapped,
                      onPieceDropped: _handlePieceDropped,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Move history & material advantage counter
              MoveHistoryWidget(
                moveHistory: board.moveHistory,
                whiteCaptured: board.whiteCaptured,
                blackCaptured: board.blackCaptured,
                whiteMaterialAdvantage: board.whiteMaterialAdvantage,
              ),

              const SizedBox(height: 8),

              // Bottom row: My Clock & Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClockWidget(
                    timeMs: myTimeMs,
                    isActive: isFlipped ? !isWhiteTurn : isWhiteTurn,
                    isUnlimited: widget.initialTimeSeconds <= 0,
                    playerName: widget.myPlayerName,
                    isWhite: isFlipped ? false : true,
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _sendTakebackRequest,
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text('Takeback', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF9E2AF),
                          side: const BorderSide(color: Color(0xFFF9E2AF)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
