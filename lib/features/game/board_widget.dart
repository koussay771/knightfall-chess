import 'dart:math';
import 'package:flutter/material.dart';

/// Responsive 8x8 Chess Board Widget with:
/// - Smooth Draggable & DragTarget "piece flying" with clean elevation shadow
/// - Subtle target destination indicators on legal squares when a piece is active
/// - Warm gold/yellow highlights for the last move (from & to)
/// - King in check highlighted in intense flashing red with radial glow
/// - Smooth horizontal board shake animation on illegal moves or check exposure
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
    this.lightSquareColor = const Color(0xFFEEEED2),
    this.darkSquareColor = const Color(0xFF769656),
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
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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

                  final fileChar = String.fromCharCode('a'.codeUnitAt(0) + col);
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
                    isLastMove: widget.lastMoveFrom == squareName ||
                        widget.lastMoveTo == squareName,
                    isPremove: widget.premoveFrom == squareName ||
                        widget.premoveTo == squareName,
                    isCheck: widget.checkSquare == squareName,
                    isLegalTarget: isLegalTarget,
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

  /// Parses the board placement segment of a FEN string into an 8x8 matrix.
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
  final bool isLastMove;
  final bool isPremove;
  final bool isCheck;
  final bool isLegalTarget;
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
    required this.isLastMove,
    required this.isPremove,
    required this.isCheck,
    required this.isLegalTarget,
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

    Color? overlayColor;
    if (isPremove) {
      overlayColor = const Color(0xAAFF7043); // Premove orange/red
    } else if (isSelected) {
      overlayColor = const Color(0x9966BB6A); // Selected square green
    } else if (isLastMove) {
      overlayColor = const Color(0x99F6E05E); // Rich Chess.com gold/yellow
    }

    final textColor = isLight ? darkColor : lightColor;

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
                // Highlight overlay (last move, selected, premove)
                if (overlayColor != null)
                  Positioned.fill(
                    child: Container(color: overlayColor),
                  ),

                // King in Check: Intense pulsing red warning flash
                if (isCheck)
                  const Positioned.fill(
                    child: _CheckHighlightWidget(),
                  ),

                // Rank label (top-left)
                if (showRankLabel)
                  Positioned(
                    top: 2,
                    left: 3,
                    child: Text(
                      rankLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),

                // File label (bottom-right)
                if (showFileLabel)
                  Positioned(
                    bottom: 1,
                    right: 3,
                    child: Text(
                      fileLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),

                // Move Paths & Legal Targets:
                // Subtle centered dot on empty square
                if (isLegalTarget && piece == null)
                  Center(
                    child: Container(
                      key: const Key('legal_move_dot'),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLight
                            ? Colors.black.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.28),
                      ),
                    ),
                  ),

                // Subtle hollow ring around enemy capture targets
                if (isLegalTarget && piece != null)
                  Center(
                    child: Container(
                      key: const Key('legal_capture_ring'),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.22)
                              : Colors.black.withValues(alpha: 0.32),
                          width: 4.5,
                        ),
                      ),
                    ),
                  ),

                // Piece Widget with smooth Chess.com-style Draggable
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
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: _PieceWidget(piece: piece!),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.25,
                        child: _PieceWidget(piece: piece!),
                      ),
                      onDragStarted: onTap,
                      child: _PieceWidget(piece: piece!),
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
      builder: (context, _) {
        final opacity = 0.65 + (_controller.value * 0.35);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFFFF1744).withValues(alpha: opacity),
                const Color(0xFFD50000).withValues(alpha: opacity * 0.8),
                const Color(0xFFB71C1C).withValues(alpha: opacity * 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 0.8, 1.0],
              radius: 0.95,
            ),
          ),
        );
      },
    );
  }
}

class _PieceWidget extends StatelessWidget {
  final String piece;

  const _PieceWidget({required this.piece});

  @override
  Widget build(BuildContext context) {
    final isWhite = piece == piece.toUpperCase();
    final symbol = _getSymbol(piece);

    return FittedBox(
      fit: BoxFit.contain,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 42,
            height: 1.0,
            color: isWhite ? const Color(0xFFFDFEFE) : const Color(0xFF17202A),
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _getSymbol(String piece) {
    switch (piece.toLowerCase()) {
      case 'k':
        return piece == 'K' ? '♔' : '♚';
      case 'q':
        return piece == 'Q' ? '♕' : '♛';
      case 'r':
        return piece == 'R' ? '♖' : '♜';
      case 'b':
        return piece == 'B' ? '♗' : '♝';
      case 'n':
        return piece == 'N' ? '♘' : '♞';
      case 'p':
        return piece == 'P' ? '♙' : '♟';
      default:
        return '';
    }
  }
}
