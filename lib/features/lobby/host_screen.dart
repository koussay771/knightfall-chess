import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/theme_constants.dart';
import '../../core/utils/network_utils.dart';
import '../../core/widgets/animated_background_switcher.dart';
import '../../engine/chess_board_state.dart';
import '../../network/sync_protocol.dart';
import '../../network/tcp_server.dart';
import '../../network/udp_discovery.dart';
import '../game/game_screen.dart';

enum _HostingState { setup, waiting }

class HostScreen extends ConsumerStatefulWidget {
  const HostScreen({super.key});

  @override
  ConsumerState<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends ConsumerState<HostScreen> {
  final _nameController = TextEditingController();
  final _dareController = TextEditingController();

  int _selectedTimeIndex = 1;
  String _selectedMode = AppConstants.modeStandard;
  _HostingState _hostingState = _HostingState.setup;

  String _hostIp = '192.168.1.100';
  int _hostPort = AppConstants.tcpPort;

  final String _myPlayerId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    _detectLocalIp();
  }

  Future<void> _detectLocalIp() async {
    final ip = await NetworkUtils.getLocalIpAddress();
    if (mounted && ip != null) {
      setState(() => _hostIp = ip);
    }
  }

  Future<void> _loadPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('player_name') ?? 'Player';
  }

  Future<void> _startHosting() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hosting a match server requires the native Android APK or Windows app. '
            'In Web browsers, use Join Game to connect to an existing host.',
          ),
          backgroundColor: AppColors.loss,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final name =
        _nameController.text.trim().isEmpty ? 'Host' : _nameController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);

    // Always re-resolve the IP right before starting so the QR code is fresh.
    final ip = await NetworkUtils.getLocalIpAddress();

    if (ip == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not detect a local hotspot / Wi-Fi IP address.\n'
            'Enable your mobile hotspot or connect to a Wi-Fi network, then try again.',
          ),
          backgroundColor: AppColors.loss,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final server = ref.read(tcpServerProvider.notifier);

    int boundPort;
    try {
      boundPort = await server.start();
    } on SocketException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start server: ${e.message}'),
            backgroundColor: AppColors.loss,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error starting server: $e'),
            backgroundColor: AppColors.loss,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Register waiting room state builder so any connecting client immediately
    // receives the current room status and player roster.
    server.buildRoomState = () => SyncProtocol.roomState(
          status: 'waiting',
          hostName: name,
          gameMode: _selectedMode,
          timeControl: AppConstants.timeControls[_selectedTimeIndex],
          players: [
            {
              'id': _myPlayerId,
              'name': name,
              'role': 'player',
              'isHost': true,
            },
            ...server.clients.map((c) => {
                  'id': c.playerId,
                  'name': c.name,
                  'role': c.role.name,
                  'isHost': false,
                }),
          ],
        );

    final udp = ref.read(udpDiscoveryProvider.notifier);
    await udp.startBroadcast(name, _selectedMode, port: boundPort);

    setState(() {
      _hostingState = _HostingState.waiting;
      _hostIp = ip!;
      _hostPort = boundPort;
    });

    // Broadcast initial room state
    final roomMsg = server.buildRoomState?.call();
    if (roomMsg != null) server.broadcast(roomMsg);
  }

  void _cancelHosting() {
    ref.read(udpDiscoveryProvider.notifier).stop();
    final server = ref.read(tcpServerProvider.notifier);
    server.buildRoomState = null;
    server.stop();
    setState(() => _hostingState = _HostingState.setup);
  }

  void _launchGame(ConnectedClient opponent) {
    final timeSeconds = AppConstants.timeControls[_selectedTimeIndex];
    final hostName =
        _nameController.text.trim().isEmpty ? 'Host' : _nameController.text.trim();
    final startPacket = SyncProtocol.gameStart(
      whiteId: _myPlayerId,
      blackId: opponent.playerId,
      whiteName: hostName,
      blackName: opponent.name,
      timeControl: timeSeconds,
      increment: 0,
      mode: _selectedMode,
      fen: ChessBoardState.initialFen,
      dareText:
          _selectedMode == AppConstants.modeDare ? _dareController.text.trim() : null,
    );

    final server = ref.read(tcpServerProvider.notifier);
    server.buildRoomState = null; // Exit waiting room state
    server.broadcast(startPacket);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          isHost: true,
          myPlayerId: _myPlayerId,
          myPlayerName:
              _nameController.text.trim().isEmpty ? 'Host' : _nameController.text.trim(),
          opponentName: opponent.name,
          myColor: 'white',
          initialTimeSeconds: timeSeconds,
          gameMode: _selectedMode,
          dareText:
              _selectedMode == AppConstants.modeDare ? _dareController.text.trim() : null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _hostingState == _HostingState.setup ? 'Host Match Hub' : 'Waiting Room',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hostingState == _HostingState.waiting) _cancelHosting();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: AnimatedBackgroundSwitcher(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _hostingState == _HostingState.setup
              ? _buildSetup(context)
              : _buildWaiting(context),
        ),
      ),
    );
  }

  // ── Setup Screen ──────────────────────────────────────────────────────────
  Widget _buildSetup(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('setup'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.goldFaint,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.gold, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hosting is only supported on native Android & Windows apps. '
                      'In web browsers, please use Join Match Hub to connect to a host.',
                      style: TextStyle(color: AppColors.gold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Name field
          const _Label('Your Name'),
          const SizedBox(height: 6),
          _darkTextField(
            controller: _nameController,
            hint: 'Enter your name',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 20),

          // Time Control
          const _Label('Time Control'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(AppConstants.timeControlLabels.length, (i) {
              final sel = i == _selectedTimeIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedTimeIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.neonGreenFaint : AppColors.bg3,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall),
                    border: Border.all(
                      color: sel ? AppColors.neonGreen : AppColors.border,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    AppConstants.timeControlLabels[i],
                    style: TextStyle(
                      color: sel ? AppColors.neonGreen : AppColors.textSecondary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Game Mode
          const _Label('Game Mode'),
          const SizedBox(height: 8),
          _modeCard(
            AppConstants.modeStandard,
            Icons.grid_on,
            'Standard Duel',
            'Classic FIDE chess rules',
          ),
          const SizedBox(height: 8),
          _modeCard(
            AppConstants.modeKoth,
            Icons.emoji_events,
            'King of the Hill',
            'Reach the center to win',
          ),
          const SizedBox(height: 8),
          _modeCard(
            AppConstants.modeDare,
            Icons.local_fire_department,
            'Dare & Bet',
            'Win or face the dare!',
          ),

          if (_selectedMode == AppConstants.modeDare) ...[
            const SizedBox(height: 14),
            const _Label('Dare Text'),
            const SizedBox(height: 6),
            _darkTextField(
              controller: _dareController,
              hint: 'What does the loser have to do?',
              icon: Icons.edit_outlined,
              maxLines: 2,
            ),
          ],

          const SizedBox(height: 28),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen,
                foregroundColor: AppColors.bg0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.wifi_tethering, size: 20),
              label: const Text(
                'Start Hosting',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              onPressed: _startHosting,
            ),
          ),
        ],
      ),
    );
  }

  // ── Waiting Room ──────────────────────────────────────────────────────────
  Widget _buildWaiting(BuildContext context) {
    final qrUrl = NetworkUtils.encodeQrUrl(_hostIp, _hostPort);
    final qrData = qrUrl;

    return SingleChildScrollView(
      key: const ValueKey('waiting'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.neonGreenFaint,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border:
                  Border.all(color: AppColors.neonGreen.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering,
                    color: AppColors.neonGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hosting Active (WebSockets)',
                        style: TextStyle(
                          color: AppColors.neonGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$_hostIp:$_hostPort  •  $qrUrl',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Copy URL/IP button
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: qrUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Host URL copied to clipboard!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.copy,
                      color: AppColors.neonGreen,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // QR Code
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonGreen.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Scan with Safari, Chrome, or in-app to join instantly',
              style: TextStyle(color: AppColors.textDim, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),

          // Session info row
          _InfoChipRow(
            chips: [
              _ChipData(
                label: {
                  AppConstants.modeStandard: 'Standard',
                  AppConstants.modeKoth: 'KOTH',
                  AppConstants.modeDare: 'Dare',
                }[_selectedMode]!,
                icon: Icons.sports_esports_outlined,
              ),
              _ChipData(
                label: AppConstants.timeControlLabels[_selectedTimeIndex],
                icon: Icons.timer_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Connected players
          const _Label('Connected Players'),
          const SizedBox(height: 8),
          Builder(builder: (ctx) {
            final serverState = ref.watch(tcpServerProvider);
            final players = serverState.players;

            if (players.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.hourglass_empty,
                        color: AppColors.textDim, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Waiting for opponent to connect...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }

            final opponent = players.first;
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                        color: AppColors.neonGreen.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.neonGreenFaint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text('♟', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opponent.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.check_circle,
                          color: AppColors.neonGreen, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchGame(opponent),
                    icon: const Icon(Icons.play_arrow, size: 22),
                    label: const Text(
                      'Start Match',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 20),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.loss,
              side: const BorderSide(color: AppColors.loss),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
            ),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Cancel Hosting'),
            onPressed: _cancelHosting,
          ),
        ],
      ),
    );
  }

  Widget _modeCard(String mode, IconData icon, String label, String desc) {
    final selected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            Icon(icon,
                color: selected ? AppColors.neonGreen : AppColors.textSecondary,
                size: 20),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
              const Icon(Icons.check_circle,
                  color: AppColors.neonGreen, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

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

Widget _darkTextField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textDim),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      filled: true,
      fillColor: AppColors.bg3,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        borderSide: const BorderSide(color: AppColors.neonGreen, width: 1.5),
      ),
    ),
  );
}

class _ChipData {
  final String label;
  final IconData icon;
  const _ChipData({required this.label, required this.icon});
}

class _InfoChipRow extends StatelessWidget {
  final List<_ChipData> chips;
  const _InfoChipRow({required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.icon, color: AppColors.textSecondary, size: 14),
              const SizedBox(width: 5),
              Text(
                c.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
