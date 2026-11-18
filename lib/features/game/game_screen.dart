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

  @override
  void initState() {
    super.initState();
    _whiteTimeMs = widget.initialTimeSeconds * 1000;
    _blackTimeMs = widget.initialTimeSeconds * 1000;

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
      _scrollToLatestMove();
      _checkPremoveTrigger();

      final updated = ref.read(chessBoardProvider);
      if (updated.isGameOver) {
        _handleGameEndedLocally(updated);
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

    final isMyTurn = board.currentTurn == widget.myColor;

    if (isMyTurn) {
      final selected = board.selectedSquare;

      if (selected == null) {
        ref.read(chessBoardProvider.notifier).selectSquare(square);
      } else if (selected == square) {
        ref.read(chessBoardProvider.notifier).selectSquare(square);
      } else {
        await _attemptPlayerMove(selected, square);
      }
    } else {
      _handlePremoveTap(square);
    }
  }

  Future<void> _handlePieceDropped(String from, String to) async {
    final board = ref.read(chessBoardProvider);
    if (board.isGameOver) return;

    final isMyTurn = board.currentTurn == widget.myColor;
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
    final isPawn = _isPawn(board.fen, from);
    final isPromotion = isPawn && (to.endsWith('8') || to.endsWith('1'));

    String? promoPiece = promoOverride;
    if (isPromotion && promoPiece == null) {
      promoPiece = await _showPromotionModal(widget.myColor == 'white');
      if (promoPiece == null) return;
    }

    final normalizedTo = MoveValidator.normalizeMoveTo(from, to);
    final notifier = ref.read(chessBoardProvider.notifier);
    final success =
        notifier.makeMove(from, normalizedTo, promotion: promoPiece);

    if (success) {
      if (widget.myColor == 'white') {
        _whiteTimeMs += widget.incrementSeconds * 1000;
      } else {
        _blackTimeMs += widget.incrementSeconds * 1000;
      }

      if (_fxEnabled) {
        SoundManager.instance.playMove();
      }
      _scrollToLatestMove();

      final updatedBoard = ref.read(chessBoardProvider);

      if (!widget.isBot) {
        final movePacket = SyncProtocol.move(
          from: from,
          to: normalizedTo,
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
    final promo = isPawn && (to.endsWith('8') || to.endsWith('1')) ? 'q' : null;

    ref.read(premoveProvider.notifier).clearPremove();
    _attemptPlayerMove(from, to, promoOverride: promo);
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
        revertedFen = board.fen;
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
    if (ms < 10000 && ms > 0) {
      final tenths = ((ms % 1000) / 100).floor();
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
    }
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
    final themeColors = AppThemes.boardThemes[themeId] ??
        const [Color(0xFF242A33), Color(0xFF161C24)];

    final isFlipped =
        _manualFlip ? (widget.myColor == 'white') : (widget.myColor == 'black');
    final isMyTurn = board.currentTurn == widget.myColor;

    final opponentTimeMs =
        widget.myColor == 'black' ? _whiteTimeMs : _blackTimeMs;
    final myTimeMs = widget.myColor == 'black' ? _blackTimeMs : _whiteTimeMs;

    final myAdvantage = widget.myColor == 'white'
        ? board.whiteMaterialAdvantage
        : -board.whiteMaterialAdvantage;
    final opponentAdvantage = -myAdvantage;

    return Scaffold(
      backgroundColor: const Color(0xFF0E141C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Column(
            children: [
              // ── 1. Top Header & LAN Status Bar ──
              _buildTopHeader(),
              const SizedBox(height: 4),

              // ── 2. Audio/Haptic Micro Telemetry Cue Pill ──
              _buildTelemetryPill(),
              const SizedBox(height: 6),

              // ── 3. Opponent Card Banner (Top) ──
              _buildOpponentBanner(
                opponentTimeMs: opponentTimeMs,
                isActive: !isMyTurn,
                advantage: opponentAdvantage,
              ),
              const SizedBox(height: 6),

              // ── 4. Precision 8x8 Chess Board Arena with Integrated Eval Strip ──
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
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
                          // Engine Evaluation Strip
                          Container(
                            width: 3.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F353E),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF88),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // 8x8 Board
                          Expanded(
                            child: BoardWidget(
                              fen: board.fen,
                              selectedSquare: board.selectedSquare,
                              legalTargets: board.legalTargets,
                              lastMoveFrom: board.lastMoveFrom,
                              lastMoveTo: board.lastMoveTo,
                              premoveFrom: premove.from,
                              premoveTo: premove.to,
                              checkSquare:
                                  _flashKingSquare ?? board.checkSquare,
                              flipped: isFlipped,
                              lightSquareColor: themeColors[0],
                              darkSquareColor: themeColors[1],
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

              const SizedBox(height: 6),

              // ── 5. Player HUD Banner (Bottom) ──
              _buildPlayerBanner(
                myTimeMs: myTimeMs,
                isActive: isMyTurn,
                advantage: myAdvantage,
              ),
              const SizedBox(height: 6),

              // ── 6. Horizontal Move Notation Scroll Ticker ──
              _buildMoveTicker(board.moveHistory),
              const SizedBox(height: 6),

              // ── 7. Streamlined Tactical Action Dock ──
              _buildActionDock(),
              const SizedBox(height: 6),

              // ── 8. Pinned Bottom Navigation Bar ──
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Component ───────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'KNIGHTFALL',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Color(0xFFF1FFEF),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2028),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B4B3D)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('● ',
                        style:
                            TextStyle(color: Color(0xFF00FF88), fontSize: 9)),
                    Text(
                      'LAN P2P',
                      style: TextStyle(
                        color: Color(0xFF00FF88),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _fxEnabled ? Icons.vibration : Icons.volume_off,
                  size: 20,
                  color: _fxEnabled
                      ? const Color(0xFF00FF88)
                      : const Color(0xFF849585),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Toggle FX',
                onPressed: () => setState(() => _fxEnabled = !_fxEnabled),
              ),
              const SizedBox(width: 4),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00FF88),
                ),
                child: const Center(
                  child:
                      Icon(Icons.person, size: 16, color: Color(0xFF003919)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Telemetry Pill Component ───────────────────────────────────────────────
  Widget _buildTelemetryPill() {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF161C24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.graphic_eq,
                    size: 12, color: Color(0xFF00FF88)),
                const SizedBox(width: 4),
                Text(
                  _fxEnabled ? 'AUDIO: LOW THUD' : 'AUDIO: MUTED',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Color(0xFFB9CBB9),
                  ),
                ),
                const Text(' • ',
                    style: TextStyle(fontSize: 8, color: Color(0xFF3B4B3D))),
                const Text(
                  '85MS HAPTIC TAP',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Color(0xFF00E479),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF161C24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('● ',
                    style: TextStyle(color: Color(0xFF00FF88), fontSize: 8)),
                Text(
                  '14ms Direct P2P',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB9CBB9),
                  ),
                ),
              ],
            ),
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
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF242A33)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF242A33),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    widget.opponentName.length >= 2
                        ? widget.opponentName.substring(0, 2).toUpperCase()
                        : 'OP',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDDE3EE),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.opponentName,
                        style: const TextStyle(
                          fontSize: 13,
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
                          widget.isBot ? '1500 BOT' : '2418 GM',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFE16D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text(
                        '♟ ♟ ♞',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF849585)),
                      ),
                      if (advantage > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F353E),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '+$advantage',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB9CBB9),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2028),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF00FF88)
                    : const Color(0xFF2F353E),
                width: isActive ? 1.2 : 1.0,
              ),
            ),
            child: Text(
              _formatTime(opponentTimeMs),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF00FF88)
                    : const Color(0xFFDDE3EE),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Player Banner Component ───────────────────────────────────────────────
  Widget _buildPlayerBanner({
    required int myTimeMs,
    required bool isActive,
    required int advantage,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2028),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF00FF88) : const Color(0xFF242A33),
          width: isActive ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    widget.myPlayerName.length >= 2
                        ? widget.myPlayerName.substring(0, 2).toUpperCase()
                        : 'GX',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003919),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.myPlayerName.isEmpty
                            ? 'Grandmaster_X'
                            : widget.myPlayerName,
                        style: const TextStyle(
                          fontSize: 13,
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
                        child: const Text(
                          '1845',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00FF88),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        isActive ? '● Your Turn' : '● Waiting',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? const Color(0xFF00FF88)
                              : const Color(0xFF849585),
                        ),
                      ),
                      if (advantage > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF88),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '+$advantage',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003919),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF242A33),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isActive
                  ? const [
                      BoxShadow(
                        color: Color(0x3300FF88),
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
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF00FF88)
                    : const Color(0xFFFFDB3C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Move Ticker Component ─────────────────────────────────────────────────
  Widget _buildMoveTicker(List<Map<String, dynamic>> moveHistory) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF090F16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: moveHistory.isEmpty
                ? const Text(
                    'No moves yet — game started',
                    style: TextStyle(fontSize: 11, color: Color(0xFF849585)),
                  )
                : ListView.builder(
                    controller: _moveScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: (moveHistory.length + 1) ~/ 2,
                    itemBuilder: (context, i) {
                      final moveNum = i + 1;
                      final whiteSan = moveHistory[i * 2]['san'] as String;
                      final blackSan = (i * 2 + 1 < moveHistory.length)
                          ? moveHistory[i * 2 + 1]['san'] as String
                          : null;
                      final isLatest = (i * 2 + 1 >= moveHistory.length);

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$moveNum. ',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF849585),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: (isLatest && blackSan == null)
                                  ? const Color(0xFF242A33)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              whiteSan,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: (isLatest && blackSan == null)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: (isLatest && blackSan == null)
                                    ? const Color(0xFF00FF88)
                                    : const Color(0xFFDDE3EE),
                              ),
                            ),
                          ),
                          if (blackSan != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: (i * 2 + 1 == moveHistory.length - 1)
                                    ? const Color(0xFF242A33)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                blackSan,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight:
                                      (i * 2 + 1 == moveHistory.length - 1)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color: (i * 2 + 1 == moveHistory.length - 1)
                                      ? const Color(0xFF00FF88)
                                      : const Color(0xFFDDE3EE),
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
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 14, color: Color(0xFF849585)),
              SizedBox(width: 2),
              Text(
                'PGN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF849585),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tactical Action Dock Component ─────────────────────────────────────────
  Widget _buildActionDock() {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: _DockButton(
              icon: Icons.sync_alt,
              label: 'Flip',
              onTap: () => setState(() => _manualFlip = !_manualFlip),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _DockButton(
              icon: Icons.handshake,
              label: _drawOffered ? 'Pending...' : 'Draw',
              iconColor: const Color(0xFFFFDB3C),
              onTap: _offerDraw,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _DockButton(
              icon: Icons.flag,
              label: 'Resign',
              iconColor: const Color(0xFFFFB4AB),
              textColor: const Color(0xFFFFB4AB),
              onTap: _confirmResign,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _DockButton(
              icon: Icons.undo,
              label: 'Takeback',
              iconColor: const Color(0xFF00FF88),
              textColor: const Color(0xFF00FF88),
              onTap: _sendTakebackRequest,
            ),
          ),
        ],
      ),
    );
  }

  // ── Pinned Bottom Nav Component ────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF090F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF161C24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.sports_esports,
            label: 'Play',
            isActive: false,
            onTap: () => Navigator.of(context).pop(),
          ),
          _NavItem(
            icon: Icons.hub,
            label: 'Network',
            isActive: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NetworkHubPage()),
            ),
          ),
          const _NavItem(
            icon: Icons.grid_view,
            label: 'Board',
            isActive: true,
          ),
          _NavItem(
            icon: Icons.history_edu,
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

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  const _DockButton({
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161C24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF242A33)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? const Color(0xFF00FF88) : const Color(0xFF849585);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
