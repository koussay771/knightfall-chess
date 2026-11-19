import 'dart:async';
import 'dart:math';
import 'package:chess/chess.dart' as chess_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/theme_constants.dart';
import '../../core/models/match_record.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/database_helper.dart';
import '../../core/utils/network_utils.dart';
import '../../core/utils/sound_manager.dart';
import '../../engine/bot_engine.dart';
import '../../engine/chess_board_state.dart';
import '../../engine/move_validator.dart';
import '../../engine/premove_handler.dart';
import '../../network/sync_protocol.dart';
import '../../network/tcp_client.dart';
import '../../network/tcp_server.dart';
import '../history/history_screen.dart';
import '../lobby/network_hub_page.dart';
import 'board_widget.dart';
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
  final bool isPassAndPlay;

  const GameScreen({
    super.key,
    required this.isHost,
    required this.myPlayerId,
    required this.myPlayerName,
    this.opponentName = 'Alex_V',
    required this.myColor,
    this.initialTimeSeconds = 300,
    this.incrementSeconds = 0,
    this.gameMode = 'standard',
    this.dareText,
    this.isBot = false,
    this.isPassAndPlay = false,
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
  bool _manualFlip = false;
  bool _fxEnabled = true;
  bool _drawOffered = false;
  String? _premoveStartSquare;
  final ScrollController _moveScrollController = ScrollController();

  // ── History navigation ────────────────────────────────────────────────────
  int? _viewingPlyIndex; // null = live/latest
  String _networkStatusText = 'LOCAL P2P';

  @override
  void initState() {
    super.initState();
    _whiteTimeMs = widget.initialTimeSeconds * 1000;
    _blackTimeMs = widget.initialTimeSeconds * 1000;
    _detectLocalIp();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chessBoardProvider.notifier).reset(
            mode: widget.gameMode == 'koth'
                ? GameMode.koth
                : widget.gameMode == 'dare'
                    ? GameMode.dare
                    : GameMode.standard,
          );
      ref.read(premoveProvider.notifier).clearPremove();
      if (!widget.isBot && !widget.isPassAndPlay) {
        _setupNetworkListeners();
      }
      _startClockTimer();

      if (widget.isBot && widget.myColor == 'black') {
        _triggerBotMove();
      }
    });
  }

  Future<void> _detectLocalIp() async {
    if (widget.isPassAndPlay) {
      if (mounted) setState(() => _networkStatusText = 'PASS & PLAY');
      return;
    }
    if (widget.isBot) {
      if (mounted) setState(() => _networkStatusText = 'OFFLINE BOT (1500)');
      return;
    }
    final ip = await NetworkUtils.getLocalIpAddress();
    if (mounted && ip != null) {
      setState(() => _networkStatusText = 'HOTSPOT: $ip');
    }
  }

  bool _botThinking = false;
  final ChessBot _bot = ChessBot(searchDepth: 3);
  final Random _botRng = Random();

  Future<void> _triggerBotMove() async {
    if (_botThinking || !mounted) return;
    _botThinking = true;

    final board = ref.read(chessBoardProvider);
    if (board.isGameOver) {
      _botThinking = false;
      return;
    }

    // Natural bot thinking delay (800ms - 1800ms).
    // The delay runs concurrently with Isolate minimax computation,
    // allowing the bot's clock timer to smoothly tick down on screen
    // without freezing frames or responding on the exact same frame.
    final thinkDelayMs = 800 + _botRng.nextInt(1000);
    final delayFuture = Future.delayed(Duration(milliseconds: thinkDelayMs));
    final calcFuture = _bot.findBestMove(board.fen);

    final results = await Future.wait([calcFuture, delayFuture]);
    final move = results[0] as Map<String, String>?;

    _botThinking = false;

    if (move != null && mounted) {
      final currentBoard = ref.read(chessBoardProvider);
      if (currentBoard.isGameOver) return;

      final notifier = ref.read(chessBoardProvider.notifier);
      final from = move['from']!;
      final to = move['to']!;
      final promo = move['promotion'];

      final success = notifier.makeMove(from, to, promotion: promo);
      if (success) {
        setState(() => _viewingPlyIndex = null);
        if (_fxEnabled) {
          SoundManager.instance.playMove();
        }
        _scrollToLatestMove();

        final updated = ref.read(chessBoardProvider);
        if (updated.isGameOver) {
          _handleGameEndedLocally(updated);
        } else {
          _checkPremoveTrigger();
        }
      }
    }
  }

  void _scrollToLatestMove() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_moveScrollController.hasClients) {
        _moveScrollController.animateTo(
          _moveScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Reconstruct FEN at a given 0-based ply index by replaying moves.
  String? _getFenAtPly(int plyIndex) {
    final history = ref.read(chessBoardProvider).moveHistory;
    if (plyIndex < 0 || plyIndex >= history.length) return null;
    final chess = chess_pkg.Chess();
    for (int i = 0; i <= plyIndex; i++) {
      final from = history[i]['from'] as String? ?? '';
      final to = history[i]['to'] as String? ?? '';
      final promo = history[i]['promotion'] as String?;
      final moveMap = <String, String>{'from': from, 'to': to};
      if (promo != null) moveMap['promotion'] = promo;
      chess.move(moveMap);
    }
    return chess.fen;
  }

  // ─── Networking Listeners ──────────────────────────────────────────────────

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

  void _handleIncomingMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
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

      final notifier = ref.read(chessBoardProvider.notifier);
      final moveSuccess = notifier.makeMove(from, to, promotion: promotion);
      if (!moveSuccess && fen != null) {
        notifier.applyFen(fen);
      }

      if (_fxEnabled) {
        SoundManager.instance.playMove();
      }
      setState(() => _viewingPlyIndex = null);
      _scrollToLatestMove();
      _checkPremoveTrigger();

      final updated = ref.read(chessBoardProvider);
      if (updated.isGameOver) {
        _handleGameEndedLocally(updated);
      }

      // If this device is the Host, re-broadcast the client's move to all
      // other connected clients (including spectators and web clients)
      if (widget.isHost) {
        final broadcastPacket = SyncProtocol.move(
          from: from,
          to: to,
          promotion: promotion,
          fen: updated.fen,
          whiteTimeMs: _whiteTimeMs,
          blackTimeMs: _blackTimeMs,
        );
        ref.read(tcpServerProvider.notifier).broadcast(broadcastPacket);
      }
    } else if (type == SyncProtocol.typeTakebackReq) {
      _showIncomingTakebackRequest();
    } else if (type == SyncProtocol.typeTakebackRes) {
      final accepted = msg['accepted'] as bool? ?? false;
      final revertedFen = msg['revertedFen'] as String?;
      setState(() => _takebackPending = false);

      if (accepted && revertedFen != null) {
        ref.read(chessBoardProvider.notifier).applyFen(revertedFen);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Takeback accepted!'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Takeback declined.'),
            backgroundColor: Color(0xFFFF3B5C),
          ),
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
    if (widget.isBot) return;
    if (widget.isHost) {
      ref.read(tcpServerProvider.notifier).broadcast(payload);
    } else {
      ref.read(tcpClientProvider.notifier).send(payload);
    }
  }

  // ─── Clock Timer ──────────────────────────────────────────────────────────

  void _startClockTimer() {
    if (widget.initialTimeSeconds <= 0) return;

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final board = ref.read(chessBoardProvider);
      if (board.isGameOver || _gameOverHandled) {
        timer.cancel();
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

    _saveMatchToHistory(
      result: winnerId == widget.myPlayerId ? 'win' : 'loss',
      reason: 'timeout',
    );

    _showGameOverDialog(
      'Timeout',
      winnerId == widget.myPlayerId ? 'You won on time!' : 'Time ran out!',
    );
  }

  // ─── Square Tapping & Piece Dropping Flow ──────────────────────────────────

  Future<void> _handleSquareTapped(String square) async {
    final board = ref.read(chessBoardProvider);
    if (board.isGameOver) return;

    if (_viewingPlyIndex != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Board input locked in preview mode. Tap "Return to Live" to move.'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final activeColor =
        widget.isPassAndPlay ? board.currentTurn : widget.myColor;
    final isMyTurn = widget.isPassAndPlay
        ? true
        : (board.currentTurn == widget.myColor);

    if (isMyTurn) {
      final selected = board.selectedSquare;

      // Determine if the tapped square holds one of active player's own pieces.
      final chess = chess_pkg.Chess.fromFEN(board.fen);
      final pieceOnSquare = chess.get(square);
      final activeColorEnum = activeColor == 'white'
          ? chess_pkg.Color.WHITE
          : chess_pkg.Color.BLACK;
      final isFriendly =
          pieceOnSquare != null && pieceOnSquare.color == activeColorEnum;

      if (selected == null) {
        // Nothing selected: start a new selection.
        ref.read(chessBoardProvider.notifier).selectSquare(square);
      } else if (selected == square) {
        // Tap same square again → deselect.
        ref.read(chessBoardProvider.notifier).selectSquare(square);
      } else if (isFriendly) {
        // Tapped a friendly piece while another piece is already selected.
        // Special case: if the selected piece is the King and this Rook square
        // is a legal castling target, treat it as a castling move.
        final isKingSelected =
            chess.get(selected)?.type == chess_pkg.PieceType.KING;
        if (isKingSelected && board.legalTargets.contains(square)) {
          // Castling — go through normal move flow.
          await _attemptPlayerMove(selected, square);
        } else {
          // Switch selection smoothly — no illegal-move warnings.
          ref.read(chessBoardProvider.notifier).selectSquare(square);
        }
      } else {
        // Target is an empty square or enemy piece → attempt the move.
        await _attemptPlayerMove(selected, square);
      }
    } else {
      _handlePremoveTap(square);
    }
  }

  Future<void> _handlePieceDropped(String from, String to) async {
    final board = ref.read(chessBoardProvider);
    if (board.isGameOver) return;
    if (_viewingPlyIndex != null) return;

    final isMyTurn = widget.isPassAndPlay
        ? true
        : (board.currentTurn == widget.myColor);
    if (isMyTurn) {
      await _attemptPlayerMove(from, to);
    } else {
      ref.read(premoveProvider.notifier).setPremove(from, to);
      if (_fxEnabled) {
        SoundManager.instance.playMove();
      }
    }
  }

  Future<void> _attemptPlayerMove(String from, String to,
      {String? promoOverride}) async {
    final board = ref.read(chessBoardProvider);
    final activeColor =
        widget.isPassAndPlay ? board.currentTurn : widget.myColor;
    final isPawn = _isPawn(board.fen, from);
    final isPromotion = isPawn && _isPromotionRank(activeColor, to);

    String? promoPiece = promoOverride;
    if (isPromotion && promoPiece == null) {
      promoPiece = await _showPromotionModal(activeColor == 'white');
      if (promoPiece == null) return;
    }

    final normalizedTo = MoveValidator.normalizeMoveTo(from, to);
    final notifier = ref.read(chessBoardProvider.notifier);
    final success =
        notifier.makeMove(from, normalizedTo, promotion: promoPiece);

    if (success) {
      if (activeColor == 'white') {
        _whiteTimeMs += widget.incrementSeconds * 1000;
      } else {
        _blackTimeMs += widget.incrementSeconds * 1000;
      }

      if (_fxEnabled) {
        SoundManager.instance.playMove();
      }
      setState(() => _viewingPlyIndex = null);
      _scrollToLatestMove();

      setState(() {
        _viewingPlyIndex = null;
        if (widget.isPassAndPlay) {
          _manualFlip = !_manualFlip;
        }
      });

      final updatedBoard = ref.read(chessBoardProvider);

      if (!widget.isBot && !widget.isPassAndPlay) {
        final movePacket = SyncProtocol.move(
          from: from,
          to: normalizedTo,
          promotion: promoPiece,
          fen: updatedBoard.fen,
          whiteTimeMs: _whiteTimeMs,
          blackTimeMs: _blackTimeMs,
        );
        _sendNetworkMessage(movePacket);
      } else if (widget.isBot) {
        if (!updatedBoard.isGameOver) {
          _triggerBotMove();
        }
      }

      if (updatedBoard.isGameOver) {
        _handleGameEndedLocally(updatedBoard);
      }
    } else {
      final chess = chess_pkg.Chess.fromFEN(board.fen);
      final isExposure =
          MoveValidator.wouldExposeOrLeaveInCheck(chess, from, normalizedTo);

      if (isExposure) {
        if (_fxEnabled) {
          SoundManager.instance.playIllegalMove();
        }
        final kingSq = MoveValidator.findKingSquare(chess, activeColor);
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
        notifier.selectSquare(to);
      }
    }
  }

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

    final isPawn = _isPawn(board.fen, from);
    final promo =
        isPawn && _isPromotionRank(board.currentTurn, to) ? 'q' : null;

    ref.read(premoveProvider.notifier).clearPremove();
    _attemptPlayerMove(from, to, promoOverride: promo);
  }

  bool _isPawn(String fen, String square) {
    try {
      final chess = chess_pkg.Chess.fromFEN(fen);
      return chess.get(square)?.type == chess_pkg.PieceType.PAWN;
    } catch (_) {
      return false;
    }
  }

  bool _isPromotionRank(String playerColor, String toSquare) {
    if (toSquare.length < 2) return false;
    final rank = toSquare[1];
    if (playerColor == 'white') return rank == '8';
    if (playerColor == 'black') return rank == '1';
    return false;
  }

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
        backgroundColor: const Color(0xFF161C24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Promotion Piece',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Color(0xFFF1FFEF),
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: pieces.map((p) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(ctx).pop(p['code'] as String),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF242A33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2F353E)),
                ),
                child: Text(
                  p['symbol'] as String,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Actions: Takeback, Draw, Resign ───────────────────────────────────────

  void _handleTakebackButton() {
    if (widget.isPassAndPlay) {
      final notifier = ref.read(chessBoardProvider.notifier);
      final reverted = notifier.undoMoves(1);
      if (reverted != null) {
        setState(() {
          _viewingPlyIndex = null;
          _manualFlip = !_manualFlip;
        });
        if (_fxEnabled) SoundManager.instance.playMove();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Move taken back!'),
            backgroundColor: Color(0xFF00FF88),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (widget.isBot) {
      final notifier = ref.read(chessBoardProvider.notifier);
      final reverted = notifier.undoMoves(2);
      if (reverted != null) {
        setState(() => _viewingPlyIndex = null);
        if (_fxEnabled) SoundManager.instance.playMove();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Takeback: Undid last turn!'),
            backgroundColor: Color(0xFF00FF88),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    _sendTakebackRequest();
  }

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

      String? revertedFen;
      if (isAccepted) {
        final notifier = ref.read(chessBoardProvider.notifier);
        revertedFen = notifier.undoMoves(1);
        setState(() => _viewingPlyIndex = null);
        if (_fxEnabled) SoundManager.instance.playMove();
      }

      final res = SyncProtocol.takebackRes(
        accepted: isAccepted,
        revertedFen: revertedFen,
      );
      _sendNetworkMessage(res);
    });
  }

  void _offerDraw() {
    setState(() => _drawOffered = !_drawOffered);
    if (_drawOffered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw offer sent to opponent.'),
          backgroundColor: Color(0xFFFFDB3C),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmResign() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161C24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Resignation',
          style: TextStyle(
              color: Color(0xFFFFB4AB), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to resign this match?',
          style: TextStyle(color: Color(0xFFDDE3EE)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF849585))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF93000A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              final msg = SyncProtocol.gameOver(
                reason: 'resignation',
                winnerId: widget.opponentName,
              );
              _sendNetworkMessage(msg);
              _handleGameOverReceived('resignation', widget.opponentName);
            },
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  // ─── Game Over Handling ───────────────────────────────────────────────────

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
    if (_fxEnabled) {
      SoundManager.instance.playGameOver();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161C24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF1FFEF),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFDDE3EE), fontSize: 15),
            ),
            if (widget.dareText != null && widget.dareText!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDB3C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFDB3C)),
                ),
                child: Text(
                  'Dare: ${widget.dareText}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFDB3C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: const Color(0xFF003919),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Return to Lobby',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    if (widget.initialTimeSeconds <= 0) return '∞';
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _moveScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(chessBoardProvider);
    final premove = ref.watch(premoveProvider);
    final themeId = ref.watch(boardThemeProvider);
    final pieceTheme = ref.watch(pieceThemeProvider);
    final themeColors = AppThemes.boardThemes[themeId] ??
        const [Color(0xFFCFD8DC), Color(0xFF16202C)];

    final isFlipped =
        _manualFlip ? (widget.myColor == 'white') : (widget.myColor == 'black');
    final activeIsWhite = board.currentTurn == 'white';
    final isMyTurn = widget.isPassAndPlay
        ? true
        : (board.currentTurn == widget.myColor);

    final opponentTimeMs = widget.isPassAndPlay
        ? (activeIsWhite ? _blackTimeMs : _whiteTimeMs)
        : (widget.myColor == 'black' ? _whiteTimeMs : _blackTimeMs);
    final myTimeMs = widget.isPassAndPlay
        ? (activeIsWhite ? _whiteTimeMs : _blackTimeMs)
        : (widget.myColor == 'black' ? _blackTimeMs : _whiteTimeMs);

    final myAdvantage = widget.myColor == 'white'
        ? board.whiteMaterialAdvantage
        : -board.whiteMaterialAdvantage;
    final opponentAdvantage = -myAdvantage;

    final displayedFen = _viewingPlyIndex != null
        ? (_getFenAtPly(_viewingPlyIndex!) ?? board.fen)
        : board.fen;
    final displayedMove = _viewingPlyIndex != null &&
            _viewingPlyIndex! < board.moveHistory.length
        ? board.moveHistory[_viewingPlyIndex!]
        : null;
    final displayedFrom = displayedMove != null
        ? displayedMove['from'] as String?
        : board.lastMoveFrom;
    final displayedTo = displayedMove != null
        ? displayedMove['to'] as String?
        : board.lastMoveTo;

    return Scaffold(
      backgroundColor: const Color(0xFF0E141C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: Column(
            children: [
              // ── 1. Top Header Matching "KNIGHTFALL CHESS" Mockup ──
              _buildTopHeader(),
              const SizedBox(height: 3),

              // ── 2. Opponent Card Banner with Connection Latency & Stockfish Status ──
              _buildOpponentBanner(
                opponentTimeMs: opponentTimeMs,
                isActive: !isMyTurn,
                advantage: opponentAdvantage,
              ),
              const SizedBox(height: 3),

              // ── Historical Preview Indicator Banner ──
              if (_viewingPlyIndex != null) ...[
                Container(
                  height: 28,
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E232B),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFFFDB3C), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history,
                              size: 14, color: Color(0xFFFFDB3C)),
                          const SizedBox(width: 6),
                          Text(
                            'HISTORICAL PREVIEW (${_viewingPlyIndex! + 1}/${board.moveHistory.length})',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFDB3C),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => setState(() => _viewingPlyIndex = null),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF88),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.play_arrow,
                                  size: 12, color: Color(0xFF003919)),
                              SizedBox(width: 2),
                              Text(
                                'Return to Live',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF003919),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── 3. Precision 8x8 Chess Arena Frame with Evaluation Bar ──
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090F16),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Engine Evaluation Strip (matching mockup)
                          Container(
                            width: 5.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F353E),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 130,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1FFEF),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // 8x8 Board (No green arc arrow)
                          Expanded(
                            child: BoardWidget(
                              fen: displayedFen,
                              selectedSquare: _viewingPlyIndex != null
                                  ? null
                                  : board.selectedSquare,
                              legalTargets: _viewingPlyIndex != null
                                  ? const []
                                  : board.legalTargets,
                              lastMoveFrom: displayedFrom,
                              lastMoveTo: displayedTo,
                              premoveFrom: _viewingPlyIndex != null
                                  ? null
                                  : premove.from,
                              premoveTo: _viewingPlyIndex != null
                                  ? null
                                  : premove.to,
                              checkSquare:
                                  _flashKingSquare ?? board.checkSquare,
                              flipped: isFlipped,
                              lightSquareColor: themeColors[0],
                              darkSquareColor: themeColors[1],
                              boardTheme: themeId,
                              pieceTheme: pieceTheme,
                              shakeTrigger: _shakeTrigger,
                              onSquareTapped: _handleSquareTapped,
                              onPieceDropped: _handlePieceDropped,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // ── 4. Bottom Player HUD Banner with Glowing Border ──
              _buildPlayerBanner(
                myTimeMs: myTimeMs,
                isActive: isMyTurn,
                moveCount: board.moveHistory.length ~/ 2 + 1,
              ),
              const SizedBox(height: 3),

              // ── 5. Tactical Action Controls: [ Flip ], [ Offer Draw ], [ Resign ], [ Arbiter ] ──
              _buildActionControls(),
              const SizedBox(height: 3),

              // ── 6. Micro Move Notation Ticker with PGN button ──
              _buildMoveTicker(board.moveHistory),
              const SizedBox(height: 3),

              // ── 7. Pinned Bottom Navigation: Play, Network, Board, History ──
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Component: Matching Mockup "KNIGHTFALL CHESS" ──────────────────
  Widget _buildTopHeader() {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF161C24),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF242A33)),
                ),
                child: const Center(
                  child: Text('♞', style: TextStyle(fontSize: 20, color: Color(0xFF00FF88))),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'KNIGHTFALL CHESS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: Color(0xFFF1FFEF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00FF88),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00FF88),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _networkStatusText,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00E479),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.tune, size: 20, color: Color(0xFFB9CBB9)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Quick Settings',
                onPressed: () => setState(() => _fxEnabled = !_fxEnabled),
              ),
              const SizedBox(width: 6),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00FF88),
                ),
                child: const Center(
                  child: Icon(Icons.person, size: 18, color: Color(0xFF003919)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Opponent Banner Component ─────────────────────────────────────────────
  Widget _buildOpponentBanner({
    required int opponentTimeMs,
    required bool isActive,
    required int advantage,
  }) {
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF161C24),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF242A33),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.person, size: 20, color: Color(0xFFDDE3EE)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.isPassAndPlay
                                ? (ref.read(chessBoardProvider).currentTurn ==
                                        'white'
                                    ? 'Black (Player 2)'
                                    : 'White (Player 1)')
                                : widget.opponentName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDDE3EE),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F353E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.isPassAndPlay ? 'OFFLINE' : '1790',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB9CBB9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text('● ',
                              style: TextStyle(
                                  color: Color(0xFF00FF88), fontSize: 8)),
                          Text(
                            widget.isPassAndPlay
                                ? 'Single Device (Pass & Play)'
                                : '12ms (Direct LAN)',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF00E479),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2028),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTime(opponentTimeMs),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isActive
                        ? const Color(0xFF00FF88)
                        : const Color(0xFFDDE3EE),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Piece Advantage Row & Engine Telemetry
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    '♟ ♟ ♞',
                    style: TextStyle(fontSize: 13, color: Color(0xFFDDE3EE)),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '+1',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00FF88),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'STOCKFISH 16.1',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Color(0xFFB9CBB9),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090F16),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '+0.4',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00FF88),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Player Banner Component with Glowing Left Border ──────────────────────
  Widget _buildPlayerBanner({
    required int myTimeMs,
    required bool isActive,
    required int moveCount,
  }) {
    return Column(
      children: [
        // Turn / Advantage Tracker
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFDB3C),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFFDB3C),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isPassAndPlay
                        ? '${ref.read(chessBoardProvider).currentTurn.toUpperCase()}\'S TURN'
                        : 'YOUR TURN',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFFFFDB3C),
                    ),
                  ),
                  Text(
                    ' | Move $moveCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB9CBB9),
                    ),
                  ),
                ],
              ),
              const Text(
                '♙ ♙ ♙ ♗',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2028),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                // Glowing emerald vertical accent line on left border
                Container(
                  width: 4,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00FF88),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00FF88),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar + User Details
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF343A42),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            '♟',
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF00FF88),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.isPassAndPlay
                                    ? (ref.read(chessBoardProvider).currentTurn ==
                                            'white'
                                        ? 'White (Player 1)'
                                        : 'Black (Player 2)')
                                    : (widget.myPlayerName.isEmpty
                                        ? 'Grandmaster_X'
                                        : widget.myPlayerName),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF1FFEF),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0x3300FF88),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.isPassAndPlay ? 'OFFLINE' : '1845',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00FF88),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isPassAndPlay
                                ? '${ref.read(chessBoardProvider).currentTurn.toUpperCase()} • Pass & Play Mode'
                                : 'White • Rapid Tournament',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFFB9CBB9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Active countdown clock
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242A33),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isActive
                          ? const [
                              BoxShadow(
                                color: Color(0x33FFDB3C),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      _formatTime(myTimeMs),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isActive
                            ? const Color(0xFFFFDB3C)
                            : const Color(0xFF00FF88),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Action Controls: [ Flip ], [ Takeback ], [ Offer Draw ], [ Resign ] ────
  Widget _buildActionControls() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: _TacticalButton(
              icon: Icons.swap_vert,
              label: 'Flip',
              iconColor: const Color(0xFFB9CBB9),
              onTap: () => setState(() => _manualFlip = !_manualFlip),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TacticalButton(
              icon: Icons.replay,
              label: 'Takeback',
              iconColor: const Color(0xFF00FF88),
              textColor: const Color(0xFF00FF88),
              onTap: _handleTakebackButton,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TacticalButton(
              icon: Icons.handshake,
              label: _drawOffered ? 'Pending...' : 'Offer Draw',
              iconColor: const Color(0xFFFFE16D),
              onTap: _offerDraw,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TacticalButton(
              icon: Icons.flag,
              label: 'Resign',
              iconColor: const Color(0xFFFFB4AB),
              textColor: const Color(0xFFFFB4AB),
              onTap: _confirmResign,
            ),
          ),
        ],
      ),
    );
  }

  // ── Micro Move Notation Ticker with PGN Label ─────────────────────────────
  Widget _buildMoveTicker(List<Map<String, dynamic>> moveHistory) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF090F16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: moveHistory.isEmpty
                ? const Text(
                    '1. e4 e5   2. Nf3 Nc6   3. Bb5 ...',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF849585),
                    ),
                  )
                : ListView.builder(
                    controller: _moveScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: (moveHistory.length + 1) ~/ 2,
                    itemBuilder: (context, i) {
                      final moveNum = i + 1;
                      final whitePlyIndex = i * 2;
                      final blackPlyIndex = whitePlyIndex + 1;
                      final whiteSan = moveHistory[whitePlyIndex]['san'] as String;
                      final blackSan = (blackPlyIndex < moveHistory.length)
                          ? moveHistory[blackPlyIndex]['san'] as String
                          : null;
                      final isWhiteViewing = _viewingPlyIndex == whitePlyIndex;
                      final isBlackViewing = _viewingPlyIndex == blackPlyIndex;
                      final isLatestWhite =
                          _viewingPlyIndex == null && blackSan == null;
                      final isLatestBlack = _viewingPlyIndex == null &&
                          (blackPlyIndex == moveHistory.length - 1);

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$moveNum. ',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB9CBB9),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _viewingPlyIndex = whitePlyIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isWhiteViewing
                                    ? const Color(0xFF242A33)
                                    : (isLatestWhite
                                        ? const Color(0xFF1E2631)
                                        : Colors.transparent),
                                border: isWhiteViewing
                                    ? Border.all(
                                        color: const Color(0xFFFFDB3C),
                                        width: 1)
                                    : null,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                whiteSan,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: (isWhiteViewing || isLatestWhite)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isWhiteViewing
                                      ? const Color(0xFFFFDB3C)
                                      : (isLatestWhite
                                          ? const Color(0xFF00FF88)
                                          : const Color(0xFFDDE3EE)),
                                ),
                              ),
                            ),
                          ),
                          if (blackSan != null) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _viewingPlyIndex = blackPlyIndex),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isBlackViewing
                                      ? const Color(0xFF242A33)
                                      : (isLatestBlack
                                          ? const Color(0xFF1E2631)
                                          : Colors.transparent),
                                  border: isBlackViewing
                                      ? Border.all(
                                          color: const Color(0xFFFFDB3C),
                                          width: 1)
                                      : null,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  blackSan,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: (isBlackViewing || isLatestBlack)
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isBlackViewing
                                        ? const Color(0xFFFFDB3C)
                                        : (isLatestBlack
                                            ? const Color(0xFF00FF88)
                                            : const Color(0xFFDDE3EE)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                        ],
                      );
                    },
                  ),
          ),
          // ── Interactive Navigation Controls: |< < > >| ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HistoryNavBtn(
                icon: Icons.first_page,
                tooltip: 'First move (|<)',
                enabled: moveHistory.isNotEmpty && _viewingPlyIndex != 0,
                onTap: () => setState(() => _viewingPlyIndex = 0),
              ),
              _HistoryNavBtn(
                icon: Icons.chevron_left,
                tooltip: 'Previous move (<)',
                enabled: moveHistory.isNotEmpty &&
                    (_viewingPlyIndex ?? moveHistory.length) > 0,
                onTap: () {
                  final cur = _viewingPlyIndex ?? moveHistory.length;
                  final prev = (cur - 1).clamp(0, moveHistory.length - 1);
                  setState(() => _viewingPlyIndex = prev);
                },
              ),
              _HistoryNavBtn(
                icon: Icons.chevron_right,
                tooltip: 'Next move (>)',
                enabled: _viewingPlyIndex != null,
                onTap: () {
                  if (_viewingPlyIndex == null) return;
                  if (_viewingPlyIndex! < moveHistory.length - 1) {
                    setState(() => _viewingPlyIndex = _viewingPlyIndex! + 1);
                  } else {
                    setState(() => _viewingPlyIndex = null);
                  }
                },
              ),
              _HistoryNavBtn(
                icon: Icons.last_page,
                tooltip: 'Latest / Live (>|)',
                enabled: _viewingPlyIndex != null,
                isLive: _viewingPlyIndex == null,
                onTap: () => setState(() => _viewingPlyIndex = null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pinned Bottom Nav Component ────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0E141C).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.sports_esports,
            label: 'Play',
            isActive: false,
            onTap: () => Navigator.of(context).pop(),
          ),
          _NavIcon(
            icon: Icons.radar,
            label: 'Network',
            isActive: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NetworkHubPage()),
            ),
          ),
          const _NavIcon(
            icon: Icons.grid_view,
            label: 'Board',
            isActive: true,
          ),
          _NavIcon(
            icon: Icons.emoji_events,
            label: 'History',
            isActive: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const Scaffold(body: HistoryScreen())),
            ),
          ),
        ],
      ),
    );
  }
}

class _TacticalButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _TacticalButton({
    required this.icon,
    required this.label,
    this.iconColor = const Color(0xFFB9CBB9),
    this.textColor = const Color(0xFFDDE3EE),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2028),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? const Color(0xFF00FF88)
                  : const Color(0xFFB9CBB9),
              shadows: isActive
                  ? const [
                      Shadow(
                        color: Color(0x6600FF88),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF00FF88)
                    : const Color(0xFFB9CBB9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryNavBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final bool isLive;
  final VoidCallback onTap;

  const _HistoryNavBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    this.isLive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (isLive ? const Color(0xFF00FF88) : const Color(0xFFDDE3EE))
        : const Color(0xFF454B54);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
