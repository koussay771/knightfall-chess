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
  Future<void> startBroadcast(String hostName, String gameMode, {int? port}) async {
    await _closeBroadcast();

    final bindPort = port ?? AppConstants.defaultPort;

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
      'port': bindPort,
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

  // ─── Listen (client side) ────────────────────────────────────────────────

  /// Binds to the discovery port and listens for host broadcast beacons.
  Future<void> startListening() async {
    if (_listenSocket != null) return;

    try {
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.udpPort,
        reuseAddress: true,
        reusePort: true,
      );

      _listenSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenSocket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      _pruneTimer?.cancel();
      _pruneTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _pruneStaleHosts();
      });

      state = state.copyWith(isRunning: true);
    } catch (_) {
      // Failed to bind discovery port
    }
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final raw = utf8.decode(datagram.data);
      final msg = SyncProtocol.decode(raw);
      if (msg['type'] != 'DISCOVERY') return;

      final hostName = msg['hostName'] as String? ?? 'Host';
      final gameMode = msg['gameMode'] as String? ?? 'standard';
      final port = msg['port'] as int? ?? AppConstants.defaultPort;
      final ip = datagram.address.address;

      final game = DiscoveredGame(
        ip: ip,
        port: port,
        hostName: hostName,
        gameMode: gameMode,
        timestamp: DateTime.now(),
      );

      final existingIndex = state.games.indexWhere((g) => g.ip == ip && g.port == port);
      final updated = List<DiscoveredGame>.from(state.games);

      if (existingIndex >= 0) {
        updated[existingIndex] = game;
      } else {
        updated.add(game);
      }

      state = state.copyWith(games: updated);
    } catch (_) {}
  }

  void _pruneStaleHosts() {
    final now = DateTime.now();
    final active = state.games.where((g) {
      return now.difference(g.timestamp) < const Duration(seconds: 5);
    }).toList();

    if (active.length != state.games.length) {
      state = state.copyWith(games: active);
    }
  }

  // ─── Teardown ────────────────────────────────────────────────────────────

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

  Future<void> stop() async {
    await _closeBroadcast();
    await _closeListen();
    state = state.copyWith(isRunning: false, games: []);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final udpDiscoveryProvider =
    StateNotifierProvider<UdpDiscoveryService, UdpDiscoveryState>(
  (ref) => UdpDiscoveryService(),
);
