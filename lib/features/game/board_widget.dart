import 'dart:math';
import 'package:flutter/material.dart';

/// Responsive 8x8 Precision Chess Board Widget matching Knightfall Dark HUD:
/// - Centered 8x8 custom dark slate/charcoal board
/// - Smooth arc/curve trajectory arrow with glowing green path and elevation rings
/// - Last move highlights in gold/yellow (from & to)
/// - King in check pulsing in intense red with "CHK" corner badge
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
    this.lightSquareColor = const Color(0xFF242A33),
    this.darkSquareColor = const Color(0xFF161C24),
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
        final squareSize = size / 8;

        final fromCenter = _getSquareCenter(
          widget.lastMoveFrom,
          widget.flipped,
          squareSize,
        );
        final toCenter = _getSquareCenter(
          widget.lastMoveTo,
          widget.flipped,
          squareSize,
        );

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
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF090F16),
                border: Border.all(color: const Color(0xFF2F353E), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // 8x8 Grid of squares
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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

                  // Trajectory Curve Overlay (non-blocking)
                  if (fromCenter != null && toCenter != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _TrajectoryPainter(
                            from: fromCenter,
                            to: toCenter,
                            squareSize: squareSize,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Offset? _getSquareCenter(
      String? sq, bool flipped, double squareSize) {
    if (sq == null || sq.length < 2) return null;
    final file = sq.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(sq[1]);
    if (rank == null || file < 0 || file > 7 || rank < 1 || rank > 8) {
      return null;
    }

    final row = 8 - rank;
    final col = file;

    final actualCol = flipped ? 7 - col : col;
    final actualRow = flipped ? 7 - row : row;

    return Offset(
      (actualCol + 0.5) * squareSize,
      (actualRow + 0.5) * squareSize,
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
                // Highlight: Last Move From (warm amber ghost trail)
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

                // Highlight: Last Move To (subtle amber arrival glow)
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

                // Selected square: Vibrant neon green overlay & inner glow
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x4000FF88),
                        border: Border.all(
                          color: const Color(0xFF00FF88),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // Premove: Cyber-orange corners
                if (isPremove)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0x33FF8C00),
                    ),
                  ),

                // King in Check: Intense pulsing red halo with CHK corner badge
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
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF849585),
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
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF849585),
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
      builder: (context, child) {
        final opacity = 0.35 + (_controller.value * 0.45);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFFFFB4AB).withValues(alpha: 0.2),
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

/// Trajectory overlay painter for smooth arc arrow and elevation rings
class _TrajectoryPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final double squareSize;

  const _TrajectoryPainter({
    required this.from,
    required this.to,
    required this.squareSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = from;
    final p2 = to;

    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1.0) return;

    // Normal vector perpendicular to trajectory
    final nx = -dy / dist;
    final ny = dx / dist;

    // Control point with gentle curvature
    final curveOffset = min(squareSize * 0.45, dist * 0.22);
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final ctrl = Offset(mid.dx + nx * curveOffset, mid.dy + ny * curveOffset);

    // 1. Glowing Neon Shadow Path
    final glowPaint = Paint()
      ..color = const Color(0x3300FF88)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, p2.dx, p2.dy);

    canvas.drawPath(path, glowPaint);

    // 2. Main Trajectory Stroke
    final mainPaint = Paint()
      ..color = const Color(0xFF00FF88)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, mainPaint);

    // 3. Origin Point: Gold/Amber dot
    final originPaint = Paint()..color = const Color(0xCCFFD700);
    canvas.drawCircle(p1, 3.5, originPaint);

    // 4. Destination Elevation Haptic Rings
    final ringPaint = Paint()
      ..color = const Color(0xE600FF88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawOval(
      Rect.fromCenter(
        center: p2,
        width: squareSize * 0.75,
        height: squareSize * 0.42,
      ),
      ringPaint,
    );

    final outerRingPaint = Paint()
      ..color = const Color(0x5500FF88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: p2,
        width: squareSize * 0.95,
        height: squareSize * 0.54,
      ),
      outerRingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.squareSize != squareSize;
  }
}

class _PieceWidget extends StatelessWidget {
  final String piece;

  const _PieceWidget({required this.piece});

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

    return Text(
      symbol,
      style: TextStyle(
        fontSize: 34,
        height: 1.0,
        color: isWhite ? const Color(0xFFF1FFEF) : const Color(0xFFDDE3EE),
        shadows: isWhite
            ? const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
                Shadow(
                  color: Color(0x4400FF88),
                  blurRadius: 4,
                ),
              ]
            : const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
      ),
    );
  }
}
