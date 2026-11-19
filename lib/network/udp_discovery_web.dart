import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Web stub: UDP broadcast/listen is not available in web browsers.
class UdpDiscoveryService extends StateNotifier<UdpDiscoveryState> {
  UdpDiscoveryService() : super(const UdpDiscoveryState());

  Future<void> startBroadcast(String hostName, String gameMode, {int? port}) async {}
  Future<void> startListening() async {}
  Future<void> stop() async {
    state = const UdpDiscoveryState();
  }
}

final udpDiscoveryProvider =
    StateNotifierProvider<UdpDiscoveryService, UdpDiscoveryState>(
  (ref) => UdpDiscoveryService(),
);
