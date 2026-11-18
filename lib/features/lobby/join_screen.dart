import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/theme_constants.dart';
import '../../core/utils/network_utils.dart';
import '../../network/sync_protocol.dart';
import '../../network/tcp_client.dart';
import '../../network/udp_discovery.dart';
import '../game/game_screen.dart';
import '../spectator/spectator_screen.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final String _myPlayerId = const Uuid().v4();
  bool _isConnecting = false;
  bool _directConnectExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(udpDiscoveryProvider.notifier).startListening();
      _listenForGameStart();
    });
  }

  Future<void> _loadPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nameController.text = prefs.getString('player_name') ?? 'Guest';
      });
    }
  }

  void _listenForGameStart() {
    final client = ref.read(tcpClientProvider.notifier);
    client.onMessageReceived = (msg) {
      final type = SyncProtocol.normalizeType(msg['type'] as String?);
      if (type == SyncProtocol.typeGameStart) {
        final mode = msg['mode'] as String? ?? 'standard';
        final timeControl = msg['timeControl'] as int? ?? 300;
        final dareText = msg['dareText'] as String?;
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                isHost: false,
                myPlayerId: _myPlayerId,
                myPlayerName: _nameController.text.trim().isEmpty
                    ? 'Guest'
                    : _nameController.text.trim(),
                opponentName: 'Host',
                myColor: 'black',
                initialTimeSeconds: timeControl,
                gameMode: mode,
                dareText: dareText,
              ),
            ),
          );
        }
      }
    };
  }

  Future<void> _connectToHost(String ip, int port) async {
    final name =
        _nameController.text.trim().isEmpty ? 'Guest' : _nameController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);
    final avatar = prefs.getString('player_avatar');
    final colorVal = prefs.getInt('player_color');

    setState(() => _isConnecting = true);

    final client = ref.read(tcpClientProvider.notifier);
    await client.connect(
      ip,
      port,
      playerId: _myPlayerId,
      name: name,
      role: 'player',
      avatarIcon: avatar,
      avatarColor: colorVal,
    );

    setState(() => _isConnecting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to $ip:$port — waiting for Host...'),
          backgroundColor: AppColors.neonGreenDim,
        ),
      );
    }
  }

  Future<void> _spectateHost(String ip, int port) async {
    final name =
        _nameController.text.trim().isEmpty ? 'Spectator' : _nameController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('player_avatar');
    final colorVal = prefs.getInt('player_color');

    final client = ref.read(tcpClientProvider.notifier);
    await client.connect(
      ip,
      port,
      playerId: _myPlayerId,
      name: name,
      role: 'spectator',
      avatarIcon: avatar,
      avatarColor: colorVal,
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SpectatorScreen()),
      );
    }
  }

  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.bg0,
          appBar: AppBar(
            title: const Text('Scan Host QR Code'),
            backgroundColor: AppColors.bg0,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null) {
                  final info = NetworkUtils.decodeQrPayload(raw);
                  if (info != null) {
                    Navigator.of(ctx).pop();
                    _connectToHost(info.ip, info.port);
                    return;
                  }
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final udpState = ref.watch(udpDiscoveryProvider);
    final clientState = ref.watch(tcpClientProvider);

    return Scaffold(
      backgroundColor: AppColors.bg1,
      appBar: AppBar(
        title: const Text('Join Match Hub'),
        backgroundColor: AppColors.bg1,
      ),
      body: Column(
        children: [
          // Name field — compact, always visible
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _darkTextField(
              controller: _nameController,
              hint: 'Your player name',
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 10),

          // Radar header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'ROOM RADAR',
                  style: TextStyle(
                    color: AppColors.textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                if (udpState.isRunning)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.neonGreen,
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _openQrScanner,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 14, color: AppColors.gold),
                        SizedBox(width: 4),
                        Text(
                          'Scan QR',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Room list (scrollable, Expanded)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // ── Static: ChessBot_LAN entry ──
                _RoomCard(
                  isBot: true,
                  hostName: 'ChessBot_LAN',
                  subtitle: 'STANDARD • 1500 ELO • Offline AI',
                  accentColor: AppColors.gold,
                  avatarIcon: '🤖',
                  onJoin: () {
                    final name = _nameController.text.trim().isEmpty
                        ? 'Player'
                        : _nameController.text.trim();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          isHost: true,
                          isBot: true,
                          myPlayerId: const Uuid().v4(),
                          myPlayerName: name,
                          opponentName: 'Chess Bot (1500)',
                          myColor: 'white',
                          initialTimeSeconds: 600,
                          gameMode: 'standard',
                        ),
                      ),
                    );
                  },
                  onSpectate: null,
                  isConnecting: false,
                ),
                const SizedBox(height: 8),

                // ── Live UDP rooms ──
                if (udpState.games.isEmpty && !udpState.isRunning)
                  _EmptyRadar()
                else
                  ...udpState.games.map((game) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RoomCard(
                          isBot: false,
                          hostName: game.hostName,
                          subtitle:
                              '${game.gameMode.toUpperCase()} • ${game.ip}:${game.port}',
                          accentColor: AppColors.neonGreen,
                          avatarIcon: '♟',
                          onJoin: _isConnecting
                              ? null
                              : () => _connectToHost(game.ip, game.port),
                          onSpectate: _isConnecting
                              ? null
                              : () => _spectateHost(game.ip, game.port),
                          isConnecting: _isConnecting,
                        ),
                      )),

                const SizedBox(height: 8),

                // ── Direct Connect collapsible ──
                _DirectConnectPanel(
                  expanded: _directConnectExpanded,
                  onToggle: () => setState(
                      () => _directConnectExpanded = !_directConnectExpanded),
                  ipController: _ipController,
                  isConnecting: _isConnecting,
                  onConnect: () {
                    final text = _ipController.text.trim();
                    final info = NetworkUtils.decodeQrPayload(
                      text.contains(':') ? text : '$text:${AppConstants.tcpPort}',
                    );
                    if (info != null) {
                      _connectToHost(info.ip, info.port);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Enter a valid IP:port address')),
                      );
                    }
                  },
                ),

                // ── Connected banner ──
                if (clientState.isConnected) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.neonGreenFaint,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(
                          color: AppColors.neonGreen.withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: AppColors.neonGreen, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connected! Waiting for Host to start match...',
                            style: TextStyle(
                              color: AppColors.neonGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Room Card ─────────────────────────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final bool isBot;
  final String hostName;
  final String subtitle;
  final Color accentColor;
  final String avatarIcon;
  final VoidCallback? onJoin;
  final VoidCallback? onSpectate;
  final bool isConnecting;

  const _RoomCard({
    required this.isBot,
    required this.hostName,
    required this.subtitle,
    required this.accentColor,
    required this.avatarIcon,
    required this.onJoin,
    required this.onSpectate,
    required this.isConnecting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Center(
              child: Text(avatarIcon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (onSpectate != null) ...[
            OutlinedButton(
              onPressed: onSpectate,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Spectate', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 6),
          ],
          ElevatedButton(
            onPressed: onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: AppColors.bg0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              isBot ? 'Play' : 'Join',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty Radar ───────────────────────────────────────────────────────────────
class _EmptyRadar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.radar, size: 36, color: AppColors.textDim),
          SizedBox(height: 8),
          Text(
            'Scanning for hotspot games...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'Make sure you are on the same Wi-Fi hotspot as the Host.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Direct Connect collapsible ────────────────────────────────────────────────
class _DirectConnectPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController ipController;
  final bool isConnecting;
  final VoidCallback onConnect;

  const _DirectConnectPanel({
    required this.expanded,
    required this.onToggle,
    required this.ipController,
    required this.isConnecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings_ethernet,
                    color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Direct IP Connect',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textDim,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ipController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '192.168.43.1:4545',
                    hintStyle: const TextStyle(color: AppColors.textDim),
                    filled: true,
                    fillColor: AppColors.bg3,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                      borderSide: const BorderSide(
                          color: AppColors.neonGreen, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isConnecting ? null : onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bg3,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                  elevation: 0,
                ),
                child: isConnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.neonGreen),
                      )
                    : const Text('Connect',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── shared TextField helper (same as host_screen) ────────────────────────────
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
