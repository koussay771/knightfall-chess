import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/theme_provider.dart';

/// Board & Piece Themes selector screen (Phase 4).
class ThemeScreen extends ConsumerStatefulWidget {
  const ThemeScreen({super.key});

  @override
  ConsumerState<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends ConsumerState<ThemeScreen> {
  String _selectedTheme = 'tournament_green';

  final List<Map<String, dynamic>> _themes = [
    {
      'id': 'classic_wood',
      'name': 'Classic Wood',
      'description': 'Warm natural oak and walnut finish',
      'lightSquare': const Color(0xFFF0D9B5),
      'darkSquare': const Color(0xFFB58863),
    },
    {
      'id': 'tournament_green',
      'name': 'Tournament Green',
      'description': 'Official FIDE tournament board colors',
      'lightSquare': const Color(0xFFEEEED2),
      'darkSquare': const Color(0xFF769656),
    },
    {
      'id': 'midnight_dark',
      'name': 'Midnight Dark',
      'description': 'High-contrast modern slate & dark indigo',
      'lightSquare': const Color(0xFF4A4A6A),
      'darkSquare': const Color(0xFF1E1E3A),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('board_theme') ?? 'tournament_green';
    });
  }

  Future<void> _selectTheme(String themeId) async {
    await ref.read(boardThemeProvider.notifier).setTheme(themeId);
    setState(() {
      _selectedTheme = themeId;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Board theme applied!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('Board Themes'),
        backgroundColor: const Color(0xFF181825),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _themes.length,
        itemBuilder: (context, index) {
          final theme = _themes[index];
          final isSelected = _selectedTheme == theme['id'];
          final lightSq = theme['lightSquare'] as Color;
          final darkSq = theme['darkSquare'] as Color;

          return Card(
            color: const Color(0xFF181825),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected ? const Color(0xFFA6E3A1) : const Color(0xFF313244),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _selectTheme(theme['id'] as String),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Mini 2x2 Board Preview
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black26),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: Container(color: lightSq)),
                                Expanded(child: Container(color: darkSq)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: Container(color: darkSq)),
                                Expanded(child: Container(color: lightSq)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Theme description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            theme['name'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCDD6F4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theme['description'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA6ADC8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Selected Indicator
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFFA6E3A1),
                        size: 26,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
