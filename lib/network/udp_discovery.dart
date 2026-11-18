import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'sync_protocol.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

/// A game host discovered on the local network via UDP broadcast.
class DiscoveredGame {
  final String ip;
  final int port;
  final String hostName;
  final String gameMode;
  final DateTime timestamp;

  const DiscoveredGame({
    required this.ip,
    required this.port,
    required this.hostName,
    required this.gameMode,
    required this.timestamp,
  });

  DiscoveredGame copyWith({DateTime? timestamp}) => DiscoveredGame(
        ip: ip,
        port: port,
        hostName: hostName,
        gameMode: gameMode,
        timestamp: timestamp ?? this.timestamp,
      );

  @override
  bool operator ==(Object other) =>
      other is DiscoveredGame && other.ip == ip && other.port == port;

  @override
  int get hashCode => Object.hash(ip, port);
}

// ─── State ────────────────────────────────────────────────────────────────────

class UdpDiscoveryState {
  final List<DiscoveredGame> games;
  final bool isRunning;

  const UdpDiscoveryState({this.games = const [], this.isRunning = false});

  UdpDiscoveryState copyWith({List<DiscoveredGame>? games, bool? isRunning}) =>
      UdpDiscoveryState(
        games: games ?? this.games,
        isRunning: isRunning ?? this.isRunning,
      );
}

// ─── StateNotifier ────────────────────────────────────────────────────────────

class UdpDiscoveryService extends StateNotifier<UdpDiscoveryState> {
  UdpDiscoveryService() : super(const UdpDiscoveryState());

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;
  Timer? _pruneTimer;

  // ─── Broadcast (host side) ───────────────────────────────────────────────

  /// Binds a UDP socket and starts broadcasting presence every 1500 ms.
  Future<void> startBroadcast(String hostName, String gameMode) async {
    await _closeBroadcast();

    _broadcastSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
      reusePort: true,
    );
    _broadcastSocket!.broadcastEnabled = true;

    final payload = SyncProtocol.encode({
      'type': 'DISCOVERY',
      'hostName': hostName,
      'gameMode': gameMode,
      'port': AppConstants.tcpPort,
    });
    final bytes = utf8.encode(payload);

    _broadcastTimer =
        Timer.periodic(AppConstants.udpBroadcastInterval, (_) {
      _broadcastSocket?.send(
        bytes,
        InternetAddress(AppConstants.broadcastAddress),
        AppConstants.udpPort,
      );
    });

    state = state.copyWith(isRunning: true);
  }

  // ─── Listen (client / spectator side) ───────────────────────────────────

  /// Binds on UDP port 4546, listens for broadcast packets and maintains the
  /// live [games] list. Stale entries (> 5 s old) are pruned every second.
  Future<void> startListening() async {
    await _closeListen();

    _listenSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      AppConstants.udpPort,
      reuseAddress: true,
      reusePort: true,
    );

    _listenSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _listenSocket!.receive();
        if (datagram == null) return;
        _handleDatagram(datagram);
      }
    });

    // Prune stale entries every second
    _pruneTimer = Timer.periodic(const Duration(seconds: 1), (_) => _prune());

    state = state.copyWith(isRunning: true);
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final raw = utf8.decode(datagram.data);
      final map = SyncProtocol.decode(raw);
      if (map['type'] != 'DISCOVERY') return;

      final ip = datagram.address.address;
      final port = (map['port'] as num?)?.toInt() ?? AppConstants.tcpPort;
      final hostName = (map['hostName'] as String?) ?? 'Unknown';
      final gameMode = (map['gameMode'] as String?) ?? 'standard';

      final incoming = DiscoveredGame(
        ip: ip,
        port: port,
        hostName: hostName,
        gameMode: gameMode,
        timestamp: DateTime.now(),
      );

      final current = List<DiscoveredGame>.from(state.games);
      final idx = current.indexWhere((g) => g == incoming);
      if (idx >= 0) {
        current[idx] = current[idx].copyWith(timestamp: DateTime.now());
      } else {
        current.add(incoming);
      }
      state = state.copyWith(games: current);
    } catch (_) {
      // Malformed packet — ignore
    }
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 5));
    final fresh = state.games.where((g) => g.timestamp.isAfter(cutoff)).toList();
    if (fresh.length != state.games.length) {
      state = state.copyWith(games: fresh);
    }
  }

  // ─── Stop ────────────────────────────────────────────────────────────────

  Future<void> stop() async {
    await _closeBroadcast();
    await _closeListen();
    state = state.copyWith(isRunning: false);
  }

  Future<void> _closeBroadcast() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  Future<void> _closeListen() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _listenSocket?.close();
    _listenSocket = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ─── Riverpod provider ───────────────────────────────────────────────────────

final udpDiscoveryProvider =
    StateNotifierProvider<UdpDiscoveryService, UdpDiscoveryState>(
  (ref) => UdpDiscoveryService(),
);
