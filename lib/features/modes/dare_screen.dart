import 'package:flutter/material.dart';

/// Bet & Dare Mode Selection & Setup Screen (Phase 3).
class DareScreen extends StatefulWidget {
  final void Function(String dareText)? onDareConfirmed;

  const DareScreen({super.key, this.onDareConfirmed});

  @override
  State<DareScreen> createState() => _DareScreenState();
}

class _DareScreenState extends State<DareScreen> {
  final TextEditingController _customDareController = TextEditingController();

  final List<String> _presetDares = [
    'Loser buys coffee for the winner ☕',
    'Loser does 20 pushups immediately 💪',
    'Loser buys lunch tomorrow 🍕',
    'Loser plays blindfold next round 🙈',
    'Loser has to give a 1-minute speech praising the winner 🎤',
  ];

  String? _selectedDare;

  @override
  void dispose() {
    _customDareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('Bet & Dare Challenge'),
        backgroundColor: const Color(0xFF181825),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF38BA8), Color(0xFFFAB387)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Text('⚡', style: TextStyle(fontSize: 36)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bet & Dare Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF11111B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Raise the stakes! Loser must fulfill the dare challenge.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF313244)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Select a Preset Challenge',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCDD6F4),
              ),
            ),
            const SizedBox(height: 10),

            ..._presetDares.map((dare) {
              final isSelected = _selectedDare == dare;
              return Card(
                color: isSelected ? const Color(0xFF45475A) : const Color(0xFF181825),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFF9E2AF) : const Color(0xFF313244),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    setState(() {
                      _selectedDare = dare;
                      _customDareController.clear();
                    });
                  },
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? const Color(0xFFF9E2AF) : const Color(0xFF6C7086),
                  ),
                  title: Text(dare, style: const TextStyle(color: Color(0xFFCDD6F4))),
                ),
              );
            }),

            const SizedBox(height: 16),
            const Text(
              'Or Write Your Own Custom Dare',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9399B2),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _customDareController,
              onChanged: (val) {
                if (val.isNotEmpty && _selectedDare != null) {
                  setState(() => _selectedDare = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'e.g. Loser must do 15 jumping jacks...',
                hintStyle: const TextStyle(color: Color(0xFF6C7086)),
                filled: true,
                fillColor: const Color(0xFF181825),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF313244)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                final text = _customDareController.text.trim().isNotEmpty
                    ? _customDareController.text.trim()
                    : _selectedDare;

                if (text != null && text.isNotEmpty) {
                  widget.onDareConfirmed?.call(text);
                  Navigator.of(context).pop(text);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select or enter a dare!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF38BA8),
                foregroundColor: const Color(0xFF11111B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm Challenge', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
