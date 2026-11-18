import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/theme_constants.dart';
import '../../core/models/match_record.dart';

/// Full-screen PGN Tactical Inspector — opened as a push route from HistoryScreen.
class PgnInspectorPage extends StatelessWidget {
  final MatchRecord match;

  const PgnInspectorPage({super.key, required this.match});

  String get _pgn {
    if (match.moves.isEmpty) return '(No moves recorded)';
    final buf = StringBuffer();
    for (int i = 0; i < match.moves.length; i++) {
      if (i % 2 == 0) buf.write('${(i ~/ 2) + 1}. ');
      buf.write('${match.moves[i]} ');
    }
    return buf.toString().trim();
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final res = match.result.toLowerCase();
    final (resColor, resLabel) = switch (res) {
      'win' => (AppColors.win, 'WIN'),
      'loss' => (AppColors.loss, 'LOSS'),
      _ => (AppColors.draw, 'DRAW'),
    };

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text('PGN Tactical Inspector'),
        backgroundColor: AppColors.bg0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Copy PGN',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _pgn));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PGN copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Match Metadata Header ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(color: resColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: resColor.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSmall),
                        border: Border.all(color: resColor.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        resLabel,
                        style: TextStyle(
                          color: resColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'vs ${match.opponentName}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MetaRow(label: 'Date', value: _fmtDate(match.date)),
                _MetaRow(
                    label: 'Result', value: '${match.result} by ${match.reason}'),
                _MetaRow(label: 'Mode', value: match.mode.toUpperCase()),
                _MetaRow(label: 'Moves', value: '${match.moves.length}'),
                if (match.dareText != null && match.dareText!.isNotEmpty)
                  _MetaRow(label: 'Dare', value: match.dareText!),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Move Stream ──
          _SectionHeader(
            title: 'Move Stream',
            trailing: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _pgn));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('PGN copied'),
                      duration: Duration(seconds: 1)),
                );
              },
              child: const Row(
                children: [
                  Icon(Icons.copy, size: 13, color: AppColors.gold),
                  SizedBox(width: 4),
                  Text(
                    'Copy PGN',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (match.moves.isEmpty)
            const _EmptyMoves()
          else
            _MoveGrid(moves: match.moves),

          const SizedBox(height: 16),

          // ── Engine Analysis placeholder ──
          const _SectionHeader(title: 'Engine Analysis'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology_outlined,
                        color: AppColors.textDim, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Engine Vector Ratings',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Full Stockfish analysis coming soon.\n'
                  'Connect a Stockfish engine to get move-by-move evaluation, '
                  'best lines, and blunder detection.',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                // Placeholder evaluation bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.55,
                    backgroundColor: AppColors.loss.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(AppColors.neonGreen),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('White +0.3',
                        style: TextStyle(
                            color: AppColors.textDim, fontSize: 10)),
                    Text('Balanced',
                        style: TextStyle(
                            color: AppColors.textDim, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Move Grid ─────────────────────────────────────────────────────────────────
class _MoveGrid extends StatelessWidget {
  final List<String> moves;
  const _MoveGrid({required this.moves});

  @override
  Widget build(BuildContext context) {
    final pairs = <(int, String, String?)>[];
    for (int i = 0; i < moves.length; i += 2) {
      pairs.add((
        i ~/ 2 + 1,
        moves[i],
        i + 1 < moves.length ? moves[i + 1] : null,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: pairs.map((p) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${p.$1}.',
                style: const TextStyle(
                    color: AppColors.textDim, fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 3),
              _MoveChip(move: p.$2, isWhite: true),
              if (p.$3 != null) ...[
                const SizedBox(width: 2),
                _MoveChip(move: p.$3!, isWhite: false),
              ],
              const SizedBox(width: 6),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String move;
  final bool isWhite;
  const _MoveChip({required this.move, required this.isWhite});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isWhite
            ? AppColors.textPrimary.withValues(alpha: 0.08)
            : AppColors.textDim.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        move,
        style: TextStyle(
          color: isWhite ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 12,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyMoves extends StatelessWidget {
  const _EmptyMoves();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Text(
          'No moves recorded for this match.',
          style: TextStyle(color: AppColors.textDim, fontSize: 12),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textDim,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Meta Row ──────────────────────────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
