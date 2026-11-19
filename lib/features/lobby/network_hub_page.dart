import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/theme_constants.dart';
import 'host_screen.dart';
import 'join_screen.dart';

/// Network Hub tab — two large action cards opening Host/Join sub-pages.
class NetworkHubPage extends StatelessWidget {
  const NetworkHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.wifi, color: AppColors.neonGreen, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Network Hub',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Host or join a local hotspot match',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Host Match Hub card
            _HubCard(
              icon: Icons.wifi_tethering,
              iconColor: AppColors.neonGreen,
              title: 'Host Match Hub',
              subtitle: 'Create a room · Share QR code · Control settings',
              accentColor: AppColors.neonGreen,
              onTap: () {
                if (kIsWeb) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Hosting a match server requires the native Android APK or Windows app. '
                        'In Web browsers, use Join Match Hub to connect to an existing host.',
                      ),
                      backgroundColor: AppColors.loss,
                      duration: Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HostScreen()),
                );
              },
              badgeLabel: 'HOST',
            ),
            const SizedBox(height: 14),

            // Join Match Hub card
            _HubCard(
              icon: Icons.radar,
              iconColor: AppColors.gold,
              title: 'Join Match Hub',
              subtitle: 'Radar scan · ChessBot_LAN · Manual IP connect',
              accentColor: AppColors.gold,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JoinScreen()),
              ),
              badgeLabel: 'JOIN',
            ),

            const Spacer(),

            // Info footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.textDim, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Both devices must be on the same Wi-Fi hotspot. '
                      'Enable your mobile hotspot before hosting.',
                      style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final String badgeLabel;

  const _HubCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    required this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: accentColor.withValues(alpha: 0.7),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
