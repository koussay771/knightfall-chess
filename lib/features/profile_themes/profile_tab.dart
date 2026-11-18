import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/theme_constants.dart';
import '../../core/providers/theme_provider.dart';
import 'theme_screen.dart';

/// Profile + Theme tab content — zero-scroll, compact, hosted in LobbyScreen tabs.
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final _nameCtrl = TextEditingController();
  String _selectedAvatar = '♟️';
  Color _selectedColor = const Color(0xFF39FF7E);
  bool _saving = false;

  static const _avatars = [
    '♟️', '🦁', '🐯', '🦅', '🔥', '⚡', '💎', '👑', '🏆', '🎯', '🐉', '🐺',
  ];
  static const _colors = [
    AppColors.neonGreen,
    AppColors.gold,
    Color(0xFF89B4FA),
    Color(0xFFF38BA8),
    Color(0xFFCBA6F7),
    Color(0xFFFAB387),
    Color(0xFF94E2D5),
    Color(0xFFA6E3A1),
  ];

  static const _boardThemeKeys = [
    'green',
    'blue-marble',
    'wood',
    'grey',
    'metal',
    'leather',
  ];
  static const _boardThemeLabels = [
    'Tournament Green',
    'Blue Marble',
    'Classic Wood',
    'Midnight Dark',
    'Titanium Metal',
    'Vintage Leather',
  ];

  static const _pieceThemeKeys = [
    'cburnett',
    'alpha',
    'merida',
    'staunty',
    'pixel',
    'rhosgfx',
  ];
  static const _pieceThemeLabels = [
    'CBurnett',
    'Alpha',
    'Merida',
    'Staunty',
    'Pixel 8-Bit',
    'Rhos GFX',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nameCtrl.text = prefs.getString('player_name') ?? 'Player';
        _selectedAvatar = prefs.getString('player_avatar') ?? '♟️';
        final cv = prefs.getInt('player_color');
        if (cv != null) _selectedColor = Color(cv);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', _nameCtrl.text.trim());
    await prefs.setString('player_avatar', _selectedAvatar);
    await prefs.setInt('player_color', _selectedColor.toARGB32());
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved!'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeId = ref.watch(boardThemeProvider);
    final currentPieceTheme = ref.watch(pieceThemeProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.neonGreen, size: 22),
                const SizedBox(width: 8),
                Text('Profile & Themes',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: 14),

            // ── Profile preview card ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLarge),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _selectedColor, width: 2),
                    ),
                    child: Center(
                      child: Text(_selectedAvatar,
                          style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameCtrl.text.isEmpty
                              ? 'Your Name'
                              : _nameCtrl.text,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'ELO 1200 • Local Player',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Username ──
            const _Label('Username'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: const TextStyle(color: AppColors.textDim),
                prefixIcon: const Icon(Icons.badge_outlined,
                    color: AppColors.textSecondary, size: 18),
                filled: true,
                fillColor: AppColors.bg3,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
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
                  borderSide: const BorderSide(
                      color: AppColors.neonGreen, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Avatar ──
            const _Label('Avatar'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _avatars.map((a) {
                final sel = _selectedAvatar == a;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = a),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: sel ? _selectedColor.withValues(alpha: 0.15) : AppColors.bg3,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                      border: Border.all(
                        color: sel ? _selectedColor : AppColors.border,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child:
                        Center(child: Text(a, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // ── Accent Color ──
            const _Label('Accent Color'),
            const SizedBox(height: 8),
            Row(
              children: _colors.map((c) {
                final sel = _selectedColor == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Save button ──
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedColor,
                  foregroundColor: AppColors.bg0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                  elevation: 0,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Profile',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: _saving ? null : _save,
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),

            // ── Board Themes ──
            const _Label('Board Theme'),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
              ),
              itemCount: _boardThemeKeys.length,
              itemBuilder: (ctx, i) {
                final key = _boardThemeKeys[i];
                final label = _boardThemeLabels[i];
                final colors = AppThemes.boardThemes[key]!;
                final selected = currentThemeId == key;

                return GestureDetector(
                  onTap: () =>
                      ref.read(boardThemeProvider.notifier).setTheme(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                        color: selected
                            ? AppColors.neonGreen
                            : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Mini board preview with real asset texture
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft:
                                Radius.circular(AppDimensions.radiusMedium - 1),
                            bottomLeft:
                                Radius.circular(AppDimensions.radiusMedium - 1),
                          ),
                          child: SizedBox(
                            width: 48,
                            height: double.infinity,
                            child: Image.asset(
                              AppThemes.getBoardTheme(key).thumbnailPath ??
                                  AppThemes.getBoardTheme(key).assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2),
                                itemCount: 4,
                                itemBuilder: (_, j) => Container(
                                  color: (j % 2 == (j ~/ 2) % 2)
                                      ? colors[0]
                                      : colors[1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.neonGreen
                                  : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (selected)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.check_circle,
                                color: AppColors.neonGreen, size: 14),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            const Divider(color: AppColors.border),
            const SizedBox(height: 10),

            // ── Piece Themes ──
            const _Label('Piece Style Theme'),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
              ),
              itemCount: _pieceThemeKeys.length,
              itemBuilder: (ctx, i) {
                final key = _pieceThemeKeys[i];
                final label = _pieceThemeLabels[i];
                final selected = currentPieceTheme == key;

                return GestureDetector(
                  onTap: () =>
                      ref.read(pieceThemeProvider.notifier).setTheme(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                        color: selected
                            ? AppColors.neonGreen
                            : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Mini piece preview
                        Container(
                          width: 44,
                          height: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16202C),
                            borderRadius: BorderRadius.only(
                              topLeft:
                                  Radius.circular(AppDimensions.radiusMedium - 1),
                              bottomLeft:
                                  Radius.circular(AppDimensions.radiusMedium - 1),
                            ),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              AppThemes.getPieceSet(key).getPieceAsset('N'),
                              width: 22,
                              height: 22,
                              fit: BoxFit.contain,
                              placeholderBuilder: (_) => const Text(
                                '♞',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF00FF88),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.neonGreen
                                  : AppColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (selected)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.check_circle,
                                color: AppColors.neonGreen, size: 14),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ThemeScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00FF88),
                  side: const BorderSide(color: Color(0xFF00FF88)),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                ),
                icon: const Icon(Icons.grid_view, size: 18),
                label: const Text(
                  'OPEN VISUAL RIG STUDIO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textDim,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}
