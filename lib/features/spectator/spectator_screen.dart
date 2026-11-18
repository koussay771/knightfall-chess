import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/theme_constants.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/utils/sound_manager.dart';
import '../../engine/chess_board_state.dart';
import '../../network/sync_protocol.dart';
import '../../network/tcp_client.dart';
import '../game/board_widget.dart';
import '../game/clock_widget.dart';
import '../game/move_history_widget.dart';

/// Read-only live spectator view for 3rd+ devices on the local hotspot.
class SpectatorScreen extends ConsumerStatefulWidget {
  final String playerWhiteName;
  final String playerBlackName;

  const SpectatorScreen({
    super.key,
    this.playerWhiteName = 'White',
    this.playerBlackName = 'Black',
  });

  @override
  ConsumerState<SpectatorScreen> createState() => _SpectatorScreenState();
}

class _SpectatorScreenState extends ConsumerState<SpectatorScreen> {
  bool _flipped = false;
  int _whiteTimeMs = 300000;
  int _blackTimeMs = 300000;
  String _currentFen = ChessBoardState.initialFen;
  String? _lastMoveFrom;
  String? _lastMoveTo;
  final List<Map<String, dynamic>> _moveHistory = [];
  final List<String> _whiteCaptured = [];
  final List<String> _blackCaptured = [];
  int _whiteMaterialAdvantage = 0;
  String _turn = 'white';
  bool _isGameOver = false;
  String? _gameOverBanner;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNetworkListener();
      _startClockCountdown();
    });
  }

  void _setupNetworkListener() {
    final client = ref.read(tcpClientProvider.notifier);
    client.onMessageReceived = (msg) {
      final type = SyncProtocol.normalizeType(msg['type'] as String?);

      if (type == SyncProtocol.typeSyncState) {
        // Initial SYNC_STATE when joining or reconnecting
        final fen = msg['fen'] as String;
        final history = List<String>.from(msg['moveHistory'] as List? ?? []);
        final wMs = msg['whiteTimeMs'] as int? ?? _whiteTimeMs;
        final bMs = msg['blackTimeMs'] as int? ?? _blackTimeMs;

        setState(() {
          _currentFen = fen;
          _whiteTimeMs = wMs;
          _blackTimeMs = bMs;
          _turn = fen.split(' ')[1] == 'w' ? 'white' : 'black';
          _moveHistory.clear();
          for (var i = 0; i < history.length; i++) {
            _moveHistory.add({
              'san': history[i],
              'color': i.isEven ? 'white' : 'black',
            });
          }
        });
      } else if (type == SyncProtocol.typeMove) {
        final from = msg['from'] as String;
        final to = msg['to'] as String;
        final fen = msg['fen'] as String?;
        final wMs = msg['whiteTimeMs'] as int?;
        final bMs = msg['blackTimeMs'] as int?;

        setState(() {
          _lastMoveFrom = from;
          _lastMoveTo = to;
          if (wMs != null) _whiteTimeMs = wMs;
          if (bMs != null) _blackTimeMs = bMs;
          if (fen != null) {
            _currentFen = fen;
            _turn = fen.split(' ')[1] == 'w' ? 'white' : 'black';
            _updateMaterialAdvantage(fen);
          }
        });

        SoundManager.instance.playMove();
      } else if (type == SyncProtocol.typeTakebackRes) {
        final accepted = msg['accepted'] as bool? ?? false;
        final revertedFen = msg['revertedFen'] as String?;
        if (accepted && revertedFen != null) {
          setState(() {
            _currentFen = revertedFen;
            _turn = revertedFen.split(' ')[1] == 'w' ? 'white' : 'black';
          });
        }
      } else if (type == SyncProtocol.typeGameOver) {
        final reason = msg['reason'] as String? ?? 'Match concluded';
        final winnerId = msg['winnerId'] as String?;

        setState(() {
          _isGameOver = true;
          _clockTimer?.cancel();
          _gameOverBanner = winnerId != null
              ? 'Game Over: Winner $winnerId ($reason)'
              : 'Game Over: Draw ($reason)';
        });
        SoundManager.instance.playGameOver();
      }
    };
  }

  void _updateMaterialAdvantage(String fen) {
    const values = {'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9};
    int w = 0;
    int b = 0;
    final placement = fen.split(' ').first;
    for (var i = 0; i < placement.length; i++) {
      final c = placement[i];
      final val = values[c.toLowerCase()];
      if (val != null) {
        if (c == c.toUpperCase()) {
          w += val;
        } else {
          b += val;
        }
      }
    }
    _whiteMaterialAdvantage = w - b;
  }

  void _startClockCountdown() {
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isGameOver) return;
      setState(() {
        if (_turn == 'white') {
          _whiteTimeMs = (_whiteTimeMs - 100).clamp(0, 99999999);
        } else {
          _blackTimeMs = (_blackTimeMs - 100).clamp(0, 99999999);
        }
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(boardThemeProvider);
    final themeColors = AppThemes.boardThemes[themeId] ?? AppThemes.boardThemes['tournament_green']!;
    final topPlayerName = _flipped ? widget.playerWhiteName : widget.playerBlackName;
    final bottomPlayerName = _flipped ? widget.playerBlackName : widget.playerWhiteName;

    final topTimeMs = _flipped ? _whiteTimeMs : _blackTimeMs;
    final bottomTimeMs = _flipped ? _blackTimeMs : _whiteTimeMs;

    final isTopActive = _flipped ? _turn == 'white' : _turn == 'black';
    final isBottomActive = _flipped ? _turn == 'black' : _turn == 'white';

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: Text(
          'Spectating: ${widget.playerWhiteName} vs ${widget.playerBlackName}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF181825),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'Flip Board',
            onPressed: () {
              setState(() {
                _flipped = !_flipped;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Spectator Badge
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF89B4FA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF89B4FA)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, size: 14, color: Color(0xFF89B4FA)),
                    SizedBox(width: 6),
                    Text(
                      'Live Spectator Mode (Read-Only)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF89B4FA),
                      ),
                    ),
                  ],
                ),
              ),

              // Game Over Banner
              if (_gameOverBanner != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF38BA8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF38BA8)),
                  ),
                  child: Text(
                    _gameOverBanner!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF38BA8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

              // Top Clock & Player Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClockWidget(
                    timeMs: topTimeMs,
                    isActive: isTopActive,
                    playerName: topPlayerName,
                    isWhite: _flipped,
                  ),
                  if (isTopActive)
                    const Chip(
                      label: Text('Thinking...', style: TextStyle(fontSize: 11)),
                      backgroundColor: Color(0xFF313244),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Read-only 8x8 Chess Board (no tap callback to prevent moves)
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: BoardWidget(
                      fen: _currentFen,
                      lastMoveFrom: _lastMoveFrom,
                      lastMoveTo: _lastMoveTo,
                      flipped: _flipped,
                      lightSquareColor: themeColors[0],
                      darkSquareColor: themeColors[1],
                      onSquareTapped: (_) {
                        // Read-only in spectator mode
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Move History & Material Counter
              MoveHistoryWidget(
                moveHistory: _moveHistory,
                whiteCaptured: _whiteCaptured,
                blackCaptured: _blackCaptured,
                whiteMaterialAdvantage: _whiteMaterialAdvantage,
              ),
              const SizedBox(height: 8),

              // Bottom Clock & Player Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClockWidget(
                    timeMs: bottomTimeMs,
                    isActive: isBottomActive,
                    playerName: bottomPlayerName,
                    isWhite: !_flipped,
                  ),
                  if (isBottomActive)
                    const Chip(
                      label: Text('Thinking...', style: TextStyle(fontSize: 11)),
                      backgroundColor: Color(0xFF313244),
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
