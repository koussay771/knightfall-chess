import 'dart:math';
import 'package:flutter/material.dart';

/// Responsive 8x8 Precision Chess Board Widget matching Knightfall Dark HUD:
/// - Centered 8x8 custom dark slate/charcoal board
/// - Clean standard square highlights ('from' and 'to' in soft gold/amber, check in soft red)
/// - NO green trajectory arc/arrow (removed for a clean, distraction-free board)
/// - King in check pulsing in soft red with subtle "CHK" micro-badge
/// - Subtle legal move glowing target dots and capture rings when active
/// - Smooth horizontal board shake animation on illegal moves
/// - Smooth piece drag-and-drop piece flying
class BoardWidget extends StatefulWidget {
  final String fen;
  final String? selectedSquare;
  final List<String> legalTargets;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? premoveFrom;
  final String? premoveTo;
  final String? checkSquare;
  final bool flipped;
  final Color lightSquareColor;
  final Color darkSquareColor;
  final String pieceTheme;
  final int shakeTrigger;
  final void Function(String square) onSquareTapped;
  final void Function(String from, String to)? onPieceDropped;

  const BoardWidget({
    super.key,
    required this.fen,
    this.selectedSquare,
    this.legalTargets = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.premoveFrom,
    this.premoveTo,
    this.checkSquare,
    this.flipped = false,
    this.lightSquareColor = const Color(0xFFCFD8DC),
    this.darkSquareColor = const Color(0xFF16202C),
    this.pieceTheme = 'tactical',
    this.shakeTrigger = 0,
    required this.onSquareTapped,
    this.onPieceDropped,
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant BoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeTrigger != oldWidget.shakeTrigger &&
        widget.shakeTrigger > 0) {
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardMatrix = _parseFenToMatrix(widget.fen);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;

        return Center(
          child: AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final val = _shakeController.value;
              final offset = sin(val * 6 * pi) * 9 * (1 - val);
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF090F16),
                border: Border.all(color: const Color(0xFF242A33), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                ),
                itemCount: 64,
                itemBuilder: (context, index) {
                  final rankIndex = index ~/ 8; // 0..7
                  final fileIndex = index % 8; // 0..7

                  final row = widget.flipped ? 7 - rankIndex : rankIndex;
                  final col = widget.flipped ? 7 - fileIndex : fileIndex;

                  final fileChar =
                      String.fromCharCode('a'.codeUnitAt(0) + col);
                  final rankChar = (8 - row).toString();
                  final squareName = '$fileChar$rankChar';

                  final isLight = (row + col) % 2 == 0;
                  final piece = boardMatrix[row][col];
                  final isLegalTarget =
                      widget.legalTargets.contains(squareName);

                  return _SquareTile(
                    squareName: squareName,
                    isLight: isLight,
                    piece: piece,
                    lightColor: widget.lightSquareColor,
                    darkColor: widget.darkSquareColor,
                    isSelected: widget.selectedSquare == squareName,
                    isLastMoveFrom: widget.lastMoveFrom == squareName,
                    isLastMoveTo: widget.lastMoveTo == squareName,
                    isPremove: widget.premoveFrom == squareName ||
                        widget.premoveTo == squareName,
                    isCheck: widget.checkSquare == squareName,
                    isLegalTarget: isLegalTarget,
                    pieceTheme: widget.pieceTheme,
                    showFileLabel:
                        widget.flipped ? rankIndex == 0 : rankIndex == 7,
                    showRankLabel:
                        widget.flipped ? fileIndex == 7 : fileIndex == 0,
                    fileLabel: fileChar,
                    rankLabel: rankChar,
                    onTap: () => widget.onSquareTapped(squareName),
                    onPieceDropped: widget.onPieceDropped,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  static List<List<String?>> _parseFenToMatrix(String fen) {
    final matrix = List.generate(8, (_) => List<String?>.filled(8, null));
    final placement = fen.split(' ').first;
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
            matrix[r][c] = char;
            c++;
          }
        }
      }
    }
    return matrix;
  }
}

class _SquareTile extends StatelessWidget {
  final String squareName;
  final bool isLight;
  final String? piece;
  final Color lightColor;
  final Color darkColor;
  final bool isSelected;
  final bool isLastMoveFrom;
  final bool isLastMoveTo;
  final bool isPremove;
  final bool isCheck;
  final bool isLegalTarget;
  final String pieceTheme;
  final bool showFileLabel;
  final bool showRankLabel;
  final String fileLabel;
  final String rankLabel;
  final VoidCallback onTap;
  final void Function(String from, String to)? onPieceDropped;

  const _SquareTile({
    required this.squareName,
    required this.isLight,
    required this.piece,
    required this.lightColor,
    required this.darkColor,
    required this.isSelected,
    required this.isLastMoveFrom,
    required this.isLastMoveTo,
    required this.isPremove,
    required this.isCheck,
    required this.isLegalTarget,
    this.pieceTheme = 'tactical',
    required this.showFileLabel,
    required this.showRankLabel,
    required this.fileLabel,
    required this.rankLabel,
    required this.onTap,
    this.onPieceDropped,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isLight ? lightColor : darkColor;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != squareName,
      onAcceptWithDetails: (details) {
        if (onPieceDropped != null) {
          onPieceDropped!(details.data, squareName);
        } else {
          onTap();
        }
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: baseColor,
            child: Stack(
              children: [
                // Highlight: Last Move From (soft gold overlay with small amber dot)
                if (isLastMoveFrom)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0x38FFD700),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xAAFFD700),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Highlight: Last Move To (soft gold arrival overlay)
                if (isLastMoveTo)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x40FFD700),
                        border: Border.all(
                          color: const Color(0x66FFD700),
                          width: 1,
                        ),
                      ),
                    ),
                  ),

                // Selected square: Soft glowing emerald overlay
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x3D00FF88),
                        border: Border.all(
                          color: const Color(0xFF00FF88),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // Premove: Cyber-orange overlay
                if (isPremove)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0x38FF8C00),
                    ),
                  ),

                // King in Check: Soft pulsing red halo with CHK corner badge
                if (isCheck) ...[
                  const Positioned.fill(
                    child: _CheckHighlightWidget(),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF690005),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: const Color(0xFFFFB4AB),
                          width: 0.8,
                        ),
                      ),
                      child: const Text(
                        'CHK',
                        style: TextStyle(
                          color: Color(0xFFFFB4AB),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],

                // Rank coordinate label (top-left)
                if (showRankLabel)
                  Positioned(
                    top: 2,
                    left: 3,
                    child: Text(
                      rankLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isLight
                            ? const Color(0xFF1A2028).withValues(alpha: 0.6)
                            : const Color(0xFFB9CBB9).withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                // File coordinate label (bottom-right)
                if (showFileLabel)
                  Positioned(
                    bottom: 1,
                    right: 3,
                    child: Text(
                      fileLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isLight
                            ? const Color(0xFF1A2028).withValues(alpha: 0.6)
                            : const Color(0xFFB9CBB9).withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                // Legal Move Target: Subtle glowing emerald dot on empty square
                if (isLegalTarget && piece == null)
                  Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x3300FF88),
                      ),
                      child: Center(
                        child: Container(
                          key: const Key('legal_move_dot'),
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00FF88),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Legal Move Capture: Hollow glowing emerald ring on occupied square
                if (isLegalTarget && piece != null)
                  Center(
                    child: Container(
                      key: const Key('legal_capture_ring'),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xCC00FF88),
                          width: 3.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4400FF88),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Chess Piece Widget with smooth elevation drag
                if (piece != null)
                  Center(
                    child: Draggable<String>(
                      data: squareName,
                      dragAnchorStrategy: pointerDragAnchorStrategy,
                      feedback: Material(
                        type: MaterialType.transparency,
                        child: Transform.scale(
                          scale: 1.18,
                          child: Container(
                            decoration: const BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black87,
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: _PieceWidget(
                              piece: piece!,
                              isSquareLight: isLight,
                              pieceTheme: pieceTheme,
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.25,
                        child: _PieceWidget(
                          piece: piece!,
                          isSquareLight: isLight,
                          pieceTheme: pieceTheme,
                        ),
                      ),
                      onDragStarted: onTap,
                      child: _PieceWidget(
                        piece: piece!,
                        isSquareLight: isLight,
                        pieceTheme: pieceTheme,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pulsing radial warning flash for King in Check
class _CheckHighlightWidget extends StatefulWidget {
  const _CheckHighlightWidget();

  @override
  State<_CheckHighlightWidget> createState() => _CheckHighlightWidgetState();
}

class _CheckHighlightWidgetState extends State<_CheckHighlightWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.28 + (_controller.value * 0.4);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFFFFB4AB).withValues(alpha: 0.25),
                const Color(0xFF93000A).withValues(alpha: opacity),
                const Color(0xFF690005).withValues(alpha: opacity * 0.95),
              ],
              stops: const [0.0, 0.75, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class _PieceWidget extends StatelessWidget {
  final String piece;
  final bool isSquareLight;
  final String pieceTheme;

  const _PieceWidget({
    required this.piece,
    required this.isSquareLight,
    this.pieceTheme = 'tactical',
  });

  static const Map<String, String> _pieceSymbols = {
    'p': '♟',
    'r': '♜',
    'n': '♞',
    'b': '♝',
    'q': '♛',
    'k': '♚',
    'P': '♙',
    'R': '♖',
    'N': '♘',
    'B': '♗',
    'Q': '♕',
    'K': '♔',
  };

  @override
  Widget build(BuildContext context) {
    final symbol = _pieceSymbols[piece] ?? '';
    final isWhite = piece == piece.toUpperCase();

    final Color pieceColor;
    final List<Shadow> shadows;

    if (pieceTheme == 'neon_phosphor') {
      if (isWhite) {
        pieceColor = const Color(0xFF00FF88);
        shadows = const [
          Shadow(color: Color(0xFF00FF88), blurRadius: 10),
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
        ];
      } else {
        pieceColor = const Color(0xFFFFD700);
        shadows = const [
          Shadow(color: Color(0xFFFFD700), blurRadius: 10),
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
        ];
      }
    } else if (pieceTheme == 'classic') {
      if (isWhite) {
        pieceColor = const Color(0xFFFAF8F5);
        shadows = const [
          Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1.5)),
        ];
      } else {
        pieceColor = const Color(0xFF1E232A);
        shadows = const [
          Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1.5)),
        ];
      }
    } else if (pieceTheme == 'obsidian') {
      if (isWhite) {
        pieceColor = const Color(0xFFE2E8F0);
        shadows = const [
          Shadow(color: Color(0x9938BDF8), blurRadius: 8, offset: Offset(0, 1)),
        ];
      } else {
        pieceColor = isSquareLight
            ? const Color(0xFF090F16)
            : const Color(0xFF1E293B);
        shadows = const [
          Shadow(color: Color(0x99EF4444), blurRadius: 8, offset: Offset(0, 1)),
        ];
      }
    } else {
      // 'tactical' - Default Tactical Grandmaster from mockup
      if (isWhite) {
        pieceColor = Colors.white;
        shadows = const [
          Shadow(
            color: Colors.black87,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ];
      } else {
        pieceColor = isSquareLight
            ? const Color(0xFF0E141C)
            : const Color(0xFFDDE3EE);
        shadows = [
          Shadow(
            color: Colors.black.withValues(alpha: isSquareLight ? 0.6 : 0.8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ];
      }
    }

    return Text(
      symbol,
      style: TextStyle(
        fontSize: 34,
        height: 1.0,
        color: pieceColor,
        shadows: shadows,
      ),
    );
  }
}
