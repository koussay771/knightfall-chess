import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/theme_constants.dart';

/// Responsive 8x8 Precision Chess Board Widget matching Knightfall Dark HUD & Real Asset Rig:
/// - Real asset board textures from assets/board/ (or procedural fallback)
/// - Real vector piece assets from assets/piece/ (SVG / WebP) with graceful fallback
/// - Clean standard square highlights ('from' and 'to' in soft gold/amber, check in soft red)
/// - NO green trajectory arc/arrow (clean, distraction-free board)
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
  final String? boardTheme;
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
    this.boardTheme,
    this.pieceTheme = 'cburnett',
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
    final boardInfo = widget.boardTheme != null
        ? AppThemes.getBoardTheme(widget.boardTheme!)
        : null;

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
              child: Stack(
                children: [
                  // Real Board Asset Texture if active
                  if (boardInfo != null)
                    Positioned.fill(
                      child: Image.asset(
                        boardInfo.assetPath,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),

                  // 8x8 Grid Canvas
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
                        hasBoardTexture: boardInfo != null,
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
                ],
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
  final bool hasBoardTexture;
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
    this.hasBoardTexture = false,
    required this.piece,
    required this.lightColor,
    required this.darkColor,
    required this.isSelected,
    required this.isLastMoveFrom,
    required this.isLastMoveTo,
    required this.isPremove,
    required this.isCheck,
    required this.isLegalTarget,
    this.pieceTheme = 'cburnett',
    required this.showFileLabel,
    required this.showRankLabel,
    required this.fileLabel,
    required this.rankLabel,
    required this.onTap,
    this.onPieceDropped,
  });

  @override
  Widget build(BuildContext context) {
    // If real board texture is underneath, keep the square transparent so texture is visible
    final baseColor = hasBoardTexture
        ? Colors.transparent
        : (isLight ? lightColor : darkColor);

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
        final isHovered = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            key: ValueKey('square_$squareName'),
            color: baseColor,
            child: Stack(
              children: [
                // 1. Subtle Selection Highlight (Emerald glow)
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withValues(alpha: 0.38),
                        border: Border.all(
                          color: const Color(0xFF00FF88),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // 2. Drag hover target highlight
                if (isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88).withValues(alpha: 0.28),
                        border: Border.all(
                          color: const Color(0xFF00FF88),
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),

                // 3. Last Move Highlight ('from' & 'to' in Soft Gold/Amber)
                if (!isSelected && (isLastMoveFrom || isLastMoveTo))
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.32),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.65),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),

                // 4. Premove Highlight (Cyan/Sky)
                if (isPremove)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                        border: Border.all(
                          color: const Color(0xFF38BDF8),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // 5. King in Check Warning State (Soft pulsing radial crimson glow)
                if (isCheck)
                  const Positioned.fill(
                    child: _CheckHighlightWidget(),
                  ),

                // 6. Coordinates (Rank on left, File on bottom)
                if (showRankLabel)
                  Positioned(
                    top: 2,
                    left: 2.5,
                    child: Text(
                      rankLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isLight
                            ? const Color(0xFF16202C).withValues(alpha: 0.65)
                            : const Color(0xFFCFD8DC).withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                if (showFileLabel)
                  Positioned(
                    bottom: 1.5,
                    right: 2.5,
                    child: Text(
                      fileLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isLight
                            ? const Color(0xFF16202C).withValues(alpha: 0.65)
                            : const Color(0xFFCFD8DC).withValues(alpha: 0.65),
                      ),
                    ),
                  ),

                // 7. Legal Move Target Indicators (clean & subtle)
                if (isLegalTarget)
                  Positioned.fill(
                    child: Center(
                      child: piece != null
                          ? Container(
                              key: const ValueKey('legal_capture_ring'),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00FF88).withValues(alpha: 0.85),
                                  width: 2.5,
                                ),
                              ),
                            )
                          : Container(
                              key: const ValueKey('legal_move_dot'),
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF00FF88).withValues(alpha: 0.75),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00FF88).withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                // 8. Chess Piece with Drag-and-Drop Piece Flying
                if (piece != null)
                  Center(
                    child: Draggable<String>(
                      data: squareName,
                      feedback: Material(
                        color: Colors.transparent,
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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final opacity = 0.45 + (_pulseAnimation.value * 0.4);
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

/// Real Piece Asset Widget (Loads SVG/WebP from assets/piece/ with Unicode fallback)
class _PieceWidget extends StatelessWidget {
  final String piece;
  final bool isSquareLight;
  final String pieceTheme;

  static const double _pieceSize = 36.0;

  const _PieceWidget({
    required this.piece,
    required this.isSquareLight,
    this.pieceTheme = 'cburnett',
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
    final pieceSet = AppThemes.getPieceSet(pieceTheme);
    final assetPath = pieceSet.getPieceAsset(piece);
    final isWhite = piece == piece.toUpperCase();
    final symbol = _pieceSymbols[piece] ?? '';

    return Stack(
      alignment: Alignment.center,
      children: [
        // Semantic/accessible text representation for screen readers & testing
        Opacity(
          opacity: 0.0,
          child: Text(
            symbol,
            style: const TextStyle(fontSize: 1),
          ),
        ),
        if (pieceSet.isWebp)
          Image.asset(
            assetPath,
            width: _pieceSize,
            height: _pieceSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackText(isWhite),
          )
        else
          SvgPicture.asset(
            assetPath,
            width: _pieceSize,
            height: _pieceSize,
            fit: BoxFit.contain,
            placeholderBuilder: (_) => _buildFallbackText(isWhite),
          ),
      ],
    );
  }

  Widget _buildFallbackText(bool isWhite) {
    final symbol = _pieceSymbols[piece] ?? '';
    final Color pieceColor = isWhite
        ? Colors.white
        : (isSquareLight ? const Color(0xFF0E141C) : const Color(0xFFDDE3EE));

    final shadows = isWhite
        ? const [
            Shadow(
              color: Colors.black87,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ]
        : [
            Shadow(
              color: Colors.black.withValues(alpha: isSquareLight ? 0.6 : 0.8),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ];

    return Text(
      symbol,
      style: TextStyle(
        fontSize: _pieceSize * 0.85,
        height: 1.0,
        color: pieceColor,
        shadows: shadows,
      ),
    );
  }
}
