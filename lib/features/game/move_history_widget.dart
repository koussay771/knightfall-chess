import 'package:flutter/material.dart';

/// Horizontal scrollable Move History & Captured Material display.
class MoveHistoryWidget extends StatefulWidget {
  final List<Map<String, dynamic>> moveHistory;
  final List<String> whiteCaptured;
  final List<String> blackCaptured;
  final int whiteMaterialAdvantage;
  final void Function(int plyIndex)? onPlySelected;
  final int? viewingPlyIndex; // null = live position

  const MoveHistoryWidget({
    super.key,
    required this.moveHistory,
    required this.whiteCaptured,
    required this.blackCaptured,
    required this.whiteMaterialAdvantage,
    this.onPlySelected,
    this.viewingPlyIndex,
  });

  @override
  State<MoveHistoryWidget> createState() => _MoveHistoryWidgetState();
}

class _MoveHistoryWidgetState extends State<MoveHistoryWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant MoveHistoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to end when new moves arrive AND when in live mode
    if (widget.moveHistory.length != oldWidget.moveHistory.length &&
        widget.viewingPlyIndex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181825),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Captured Material Row
          Row(
            children: [
              // White captures (Black pieces captured by White)
              Expanded(
                child: _CapturedPiecesBar(
                  pieces: widget.whiteCaptured,
                  isWhite: true,
                  advantage: widget.whiteMaterialAdvantage > 0
                      ? '+${widget.whiteMaterialAdvantage}'
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // Black captures (White pieces captured by Black)
              Expanded(
                child: _CapturedPiecesBar(
                  pieces: widget.blackCaptured,
                  isWhite: false,
                  advantage: widget.whiteMaterialAdvantage < 0
                      ? '+${widget.whiteMaterialAdvantage.abs()}'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFF313244)),
          const SizedBox(height: 6),

          // Scrollable Move list
          SizedBox(
            height: 28,
            child: widget.moveHistory.isEmpty
                ? const Center(
                    child: Text(
                      'No moves played yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6C7086),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: (widget.moveHistory.length + 1) ~/ 2,
                    itemBuilder: (context, turnIndex) {
                      final moveNum = turnIndex + 1;
                      final whitePlyIndex = turnIndex * 2;
                      final blackPlyIndex = whitePlyIndex + 1;

                      final whiteSan =
                          widget.moveHistory[whitePlyIndex]['san'] as String? ?? '';
                      final blackSan = blackPlyIndex < widget.moveHistory.length
                          ? widget.moveHistory[blackPlyIndex]['san'] as String? ?? ''
                          : '';

                      final isWhiteSelected = widget.viewingPlyIndex == whitePlyIndex;
                      final isBlackSelected = blackPlyIndex < widget.moveHistory.length &&
                          widget.viewingPlyIndex == blackPlyIndex;

                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$moveNum. ',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9399B2),
                              ),
                            ),
                            // White move chip
                            GestureDetector(
                              onTap: () => widget.onPlySelected?.call(whitePlyIndex),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isWhiteSelected
                                      ? const Color(0xFF242A33)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  whiteSan,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isWhiteSelected
                                        ? const Color(0xFFFFDB3C)
                                        : const Color(0xFFCDD6F4),
                                  ),
                                ),
                              ),
                            ),
                            // Black move chip
                            if (blackSan.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () =>
                                    widget.onPlySelected?.call(blackPlyIndex),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isBlackSelected
                                        ? const Color(0xFF242A33)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    blackSan,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isBlackSelected
                                          ? const Color(0xFFFFDB3C)
                                          : const Color(0xFFA6ADC8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CapturedPiecesBar extends StatelessWidget {
  final List<String> pieces;
  final bool isWhite;
  final String? advantage;

  const _CapturedPiecesBar({
    required this.pieces,
    required this.isWhite,
    this.advantage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            pieces.map(_pieceSymbol).join(' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFBAC2DE),
            ),
          ),
        ),
        if (advantage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF45475A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              advantage!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA6E3A1),
              ),
            ),
          ),
      ],
    );
  }

  String _pieceSymbol(String p) {
    switch (p.toLowerCase()) {
      case 'q':
        return '♛';
      case 'r':
        return '♜';
      case 'b':
        return '♝';
      case 'n':
        return '♞';
      case 'p':
        return '♟';
      default:
        return p;
    }
  }
}
