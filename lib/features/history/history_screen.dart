import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/theme_constants.dart';
import '../../core/models/match_record.dart';
import '../../core/utils/database_helper.dart';
import 'pgn_inspector_page.dart';

/// History tab content (no Scaffold/AppBar — hosted inside LobbyScreen tabs).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MatchRecord> _allMatches = [];
  List<MatchRecord> _filtered = [];
  bool _isLoading = true;

  int _wins = 0, _draws = 0, _losses = 0;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final matches = await DatabaseHelper.instance.getAllMatches();
      if (mounted) {
        setState(() {
          _allMatches = matches;
          _filtered = matches;
          _computeStats(matches);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _computeStats(List<MatchRecord> list) {
    int w = 0, d = 0, l = 0;
    for (final m in list) {
      if (m.result == 'win') {
        w++;
      } else if (m.result == 'draw') {
        d++;
      } else if (m.result == 'loss') {
        l++;
      }
    }
    _wins = w; _draws = d; _losses = l;
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allMatches
          : _allMatches.where((m) => m.opponentName.toLowerCase().contains(q)).toList();
      _computeStats(_filtered);
    });
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.history, color: AppColors.neonGreen, size: 22),
                const SizedBox(width: 8),
                Text('History',
                    style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                GestureDetector(
                  onTap: _load,
                  child: const Icon(Icons.refresh,
                      color: AppColors.textDim, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── W/D/L Scoreboard ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Scoreboard(
              wins: _wins,
              draws: _draws,
              losses: _losses,
              label: _searchCtrl.text.isEmpty
                  ? 'Overall Record'
                  : 'vs ${_searchCtrl.text.trim()}',
            ),
          ),
          const SizedBox(height: 10),

          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Filter by opponent...',
                hintStyle: const TextStyle(color: AppColors.textDim),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textDim, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: _searchCtrl.clear,
                        child: const Icon(Icons.clear,
                            color: AppColors.textDim, size: 16),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.bg2,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  borderSide:
                      const BorderSide(color: AppColors.neonGreen, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Match list ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonGreen))
                : _filtered.isEmpty
                    ? _EmptyHistory(hasQuery: _searchCtrl.text.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final m = _filtered[i];
                          return _MatchCard(
                            match: m,
                            formattedDate: _fmtDate(m.date),
                            onInspect: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PgnInspectorPage(match: m),
                              ),
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

// ── Scoreboard ────────────────────────────────────────────────────────────────
class _Scoreboard extends StatelessWidget {
  final int wins, draws, losses;
  final String label;

  const _Scoreboard({
    required this.wins,
    required this.draws,
    required this.losses,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textDim, fontSize: 11, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatCell(label: 'WINS', count: wins, color: AppColors.win),
              Container(
                  width: 1, height: 32, color: AppColors.border),
              _StatCell(label: 'DRAWS', count: draws, color: AppColors.draw),
              Container(
                  width: 1, height: 32, color: AppColors.border),
              _StatCell(label: 'LOSSES', count: losses, color: AppColors.loss),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatCell(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(
              color: AppColors.textDim, fontSize: 10, letterSpacing: 0.8),
        ),
      ],
    );
  }
}

// ── Match Card ────────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final MatchRecord match;
  final String formattedDate;
  final VoidCallback onInspect;

  const _MatchCard({
    required this.match,
    required this.formattedDate,
    required this.onInspect,
  });

  @override
  Widget build(BuildContext context) {
    final res = match.result.toLowerCase();
    final (bg, fg, label) = switch (res) {
      'win' => (AppColors.win.withValues(alpha: 0.12), AppColors.win, 'WIN'),
      'loss' => (
          AppColors.loss.withValues(alpha: 0.12),
          AppColors.loss,
          'LOSS'
        ),
      _ => (AppColors.draw.withValues(alpha: 0.12), AppColors.draw, 'DRAW'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Result badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              border: Border.all(color: fg.withValues(alpha: 0.6)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                    color: fg, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${match.opponentName}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${match.mode.toUpperCase()} • ${match.reason} • $formattedDate',
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Inspect button
          GestureDetector(
            onTap: onInspect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                border: Border.all(color: AppColors.borderBright),
              ),
              child: const Text(
                'Inspect PGN ›',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyHistory extends StatelessWidget {
  final bool hasQuery;
  const _EmptyHistory({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 52, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(
              hasQuery ? 'No matches found' : 'No match history yet',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              hasQuery
                  ? 'Try a different opponent name'
                  : 'Completed games are saved here automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Copy-to-clipboard helper (used by PgnInspectorPage) ──────────────────────
void copyToClipboard(BuildContext context, String text, String label) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label copied to clipboard'),
      duration: const Duration(seconds: 1),
    ),
  );
}
