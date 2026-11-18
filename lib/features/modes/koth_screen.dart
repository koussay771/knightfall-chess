import 'package:flutter/material.dart';

/// King of the Hill / Mini-Tournament Lobby Screen (Phase 3).
class KothScreen extends StatefulWidget {
  const KothScreen({super.key});

  @override
  State<KothScreen> createState() => _KothScreenState();
}

class _KothScreenState extends State<KothScreen> {
  final List<Map<String, dynamic>> _leaderboard = [
    {'name': 'King (Current Champion)', 'streak': 3, 'wins': 5},
    {'name': 'Challenger 1', 'streak': 0, 'wins': 2},
    {'name': 'Challenger 2', 'streak': 0, 'wins': 1},
  ];

  final List<String> _waitingQueue = ['Challenger 1', 'Challenger 2', 'Player 4'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('King of the Hill Tournament'),
        backgroundColor: const Color(0xFF181825),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF9E2AF), Color(0xFFFAB387)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Text('👑', style: TextStyle(fontSize: 36)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'King of the Hill',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF11111B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Winner stays on the board! Loser moves to the back of the queue.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF313244)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Live Leaderboard
            const Text(
              'Live Tournament Leaderboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCDD6F4),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: const Color(0xFF181825),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF313244)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _leaderboard.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF313244)),
                itemBuilder: (context, index) {
                  final entry = _leaderboard[index];
                  final isKing = index == 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isKing ? const Color(0xFFF9E2AF) : const Color(0xFF45475A),
                      foregroundColor: isKing ? const Color(0xFF11111B) : const Color(0xFFCDD6F4),
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      entry['name'] as String,
                      style: TextStyle(
                        fontWeight: isKing ? FontWeight.bold : FontWeight.w500,
                        color: isKing ? const Color(0xFFF9E2AF) : const Color(0xFFCDD6F4),
                      ),
                    ),
                    subtitle: Text('Streak: 🔥 ${entry['streak']}'),
                    trailing: Text(
                      '${entry['wins']} Wins',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA6E3A1),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Waiting Queue
            const Text(
              'Up Next in Queue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCDD6F4),
              ),
            ),
            const SizedBox(height: 10),
            ..._waitingQueue.asMap().entries.map((e) {
              return Card(
                color: const Color(0xFF181825),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFF313244)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Chip(
                    label: Text('#${e.key + 1}'),
                    backgroundColor: const Color(0xFF313244),
                  ),
                  title: Text(e.value, style: const TextStyle(color: Color(0xFFCDD6F4))),
                  trailing: e.key == 0
                      ? const Chip(
                          label: Text('Next Match', style: TextStyle(fontSize: 11)),
                          backgroundColor: Color(0xFF769656),
                        )
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
