import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/theme_constants.dart';
import '../../core/providers/user_profile_provider.dart';
import '../game/game_screen.dart';
import '../history/history_screen.dart';
import '../profile_themes/profile_tab.dart';
import 'host_screen.dart';
import 'join_screen.dart';
import 'network_hub_page.dart';

// ─── Lobby Root with Bottom Navigation ───────────────────────────────────────
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = [
    _PlayTab(),
    NetworkHubPage(),
    HistoryScreen(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: AppColors.bg0,
        selectedItemColor: AppColors.neonGreen,
        unselectedItemColor: AppColors.textDim,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports_outlined),
            activeIcon: Icon(Icons.sports_esports),
            label: 'Play',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi_outlined),
            activeIcon: Icon(Icons.wifi),
            label: 'Network',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─── Play Tab ─────────────────────────────────────────────────────────────────
class _PlayTab extends ConsumerStatefulWidget {
  const _PlayTab();

  @override
  ConsumerState<_PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends ConsumerState<_PlayTab> {
  int _selectedTimeIndex = 1; // 5 min default
  String _selectedMode = AppConstants.modeStandard;

  static const _modeData = [
    {
      'key': AppConstants.modeStandard,
      'icon': Icons.grid_on,
      'label': 'Standard Duel',
      'desc': 'Classic FIDE rules',
    },
    {
      'key': AppConstants.modeKoth,
      'icon': Icons.emoji_events,
      'label': 'King of the Hill',
      'desc': 'Reach center to win',
    },
    {
      'key': AppConstants.modeDare,
      'icon': Icons.local_fire_department,
      'label': 'Dare & Bet Gauntlet',
      'desc': 'Loser faces the dare',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Reactively watches the global user profile — no more manual SharedPrefs loads.
    final profile = ref.watch(userProfileProvider);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile mini-banner (reactive) ──
            _ProfileBanner(name: profile.name, avatar: profile.avatar),
            SizedBox(height: isSmall ? 8 : 12),

            // ── Time Control Chips ──
            const _SectionLabel('Time Control'),
            const SizedBox(height: 6),
            _TimeControlRow(
              selected: _selectedTimeIndex,
              onSelect: (i) => setState(() => _selectedTimeIndex = i),
            ),
            SizedBox(height: isSmall ? 8 : 12),

            // ── Game Mode Cards ──
            const _SectionLabel('Combat Format'),
            const SizedBox(height: 6),
            ..._modeData.map((m) {
              final key = m['key'] as String;
              final selected = _selectedMode == key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _ModeCard(
                  icon: m['icon'] as IconData,
                  label: m['label'] as String,
                  desc: m['desc'] as String,
                  selected: selected,
                  onTap: () => setState(() => _selectedMode = key),
                ),
              );
            }),

            const Spacer(),

            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Host Game',
                    icon: Icons.wifi_tethering,
                    color: AppColors.neonGreen,
                    textColor: AppColors.bg0,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HostScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    label: 'Join Game',
                    icon: Icons.search,
                    color: AppColors.gold,
                    textColor: AppColors.bg0,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ActionButton(
              label: 'Play vs Bot (1500 ELO)',
              icon: Icons.smart_toy_outlined,
              color: AppColors.bg3,
              textColor: AppColors.textPrimary,
              borderColor: AppColors.borderBright,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GameScreen(
                    isHost: true,
                    isBot: true,
                    myPlayerId: const Uuid().v4(),
                    myPlayerName: profile.name,
                    opponentName: 'Chess Bot (1500)',
                    myColor: 'white',
                    initialTimeSeconds:
                        AppConstants.timeControls[_selectedTimeIndex],
                    gameMode: _selectedMode,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Sub-widgets ───────────────────────────────────────────────────────

class _ProfileBanner extends StatelessWidget {
  final String name;
  final String avatar;

  const _ProfileBanner({required this.name, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.neonGreenDim, width: 1.5),
            ),
            child: Center(
              child: Text(avatar, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'ELO 1200 • Ready to play',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.neonGreenFaint,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.neonGreen, width: 0.5),
            ),
            child: const Text(
              '● ONLINE',
              style: TextStyle(
                color: AppColors.neonGreen,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textDim,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _TimeControlRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _TimeControlRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(AppConstants.timeControlLabels.length, (i) {
        final isSelected = i == selected;
        final label = AppConstants.timeControlLabels[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 6 : 0),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.neonGreenFaint : AppColors.bg3,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  border: Border.all(
                    color: isSelected ? AppColors.neonGreen : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.neonGreen
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.neonGreenFaint : AppColors.bg2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: selected ? AppColors.neonGreen : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.neonGreen : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? AppColors.neonGreen
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppColors.neonGreen,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            side: borderColor != null
                ? BorderSide(color: borderColor!)
                : BorderSide.none,
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
      ),
    );
  }
}
