import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_screen.dart';

/// Player Profile setup screen (Phase 4).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();

  final List<String> _avatarIcons = [
    '♟️', '🦁', '🐯', '🦅', '🔥', '⚡', '💎', '👑', '🏆', '🎯', '🐉', '🐺'
  ];

  final List<Color> _accentColors = const [
    Color(0xFF769656),
    Color(0xFF89B4FA),
    Color(0xFFF9E2AF),
    Color(0xFFF38BA8),
    Color(0xFFCBA6F7),
    Color(0xFFFAB387),
    Color(0xFF94E2D5),
    Color(0xFFA6E3A1),
  ];

  String _selectedAvatar = '♟️';
  Color _selectedColor = const Color(0xFF769656);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('player_name') ?? 'Player';
      _selectedAvatar = prefs.getString('player_avatar') ?? '♟️';
      final colorVal = prefs.getInt('player_color');
      if (colorVal != null) {
        _selectedColor = Color(colorVal);
      }
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', _nameController.text.trim());
    await prefs.setString('player_avatar', _selectedAvatar);
    await prefs.setInt('player_color', _selectedColor.toARGB32());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Color(0xFF769656),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('Player Profile & Customization'),
        backgroundColor: const Color(0xFF181825),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            tooltip: 'Board Themes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ThemeScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Preview Card
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: _selectedColor,
                    child: Text(
                      _selectedAvatar,
                      style: const TextStyle(fontSize: 44),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text.isEmpty
                        ? 'Player Name'
                        : _nameController.text.trim(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCDD6F4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Username Field
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.badge),
                filled: true,
                fillColor: const Color(0xFF181825),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF313244)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar Selector
            const Text(
              'Choose Avatar Icon',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFBAC2DE),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _avatarIcons.map((icon) {
                final isSelected = _selectedAvatar == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = icon),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF45475A)
                          : const Color(0xFF181825),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _selectedColor
                            : const Color(0xFF313244),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Accent Color Picker
            const Text(
              'Choose Accent Color',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFBAC2DE),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _accentColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 20, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Board Themes Link
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ThemeScreen()),
                );
              },
              icon: const Icon(Icons.style),
              label: const Text('Change Board Themes'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF89B4FA),
                side: const BorderSide(color: Color(0xFF89B4FA)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
