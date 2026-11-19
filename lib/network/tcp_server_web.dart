import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ClientRole { player, spectator }

class ConnectedClient {
  final dynamic socket;
  final String playerId;
  final String name;
  final ClientRole role;

  const ConnectedClient({
    required this.socket,
    required this.playerId,
    required this.name,
    required this.role,
  });

  ConnectedClient copyWith({ClientRole? role}) => ConnectedClient(
        socket: socket,
        playerId: playerId,
        name: name,
        role: role ?? this.role,
      );
}

class TcpServerState {
  final bool isRunning;
  final int port;
  final List<ConnectedClient> clients;

  const TcpServerState({
    this.isRunning = false,
    this.port = 8080,
    this.clients = const [],
  });

  TcpServerState copyWith({
    bool? isRunning,
    int? port,
    List<ConnectedClient>? clients,
  }) =>
      TcpServerState(
        isRunning: isRunning ?? this.isRunning,
        port: port ?? this.port,
        clients: clients ?? this.clients,
      );

  List<ConnectedClient> get players => const [];
  List<ConnectedClient> get spectators => const [];
}

typedef MessageCallback = void Function(
    String playerId, Map<String, dynamic> message);
typedef DisconnectCallback = void Function(String playerId);

/// Web stub: Hosting is only supported on native devices (Android / Windows).
class TcpServer extends StateNotifier<TcpServerState> {
  TcpServer() : super(const TcpServerState());

  int? get actualPort => null;
  MessageCallback? onMessageReceived;
  DisconnectCallback? onClientDisconnected;
  String Function()? buildSyncState;

  Future<int> start({int? port}) async {
    throw UnsupportedError(
        'Hosting is only supported on native Android and Windows devices.');
  }

  Future<void> stop() async {
    state = const TcpServerState();
  }

  void broadcast(String message) {}
  void sendTo(String playerId, String message) {}
}

final tcpServerProvider = StateNotifierProvider<TcpServer, TcpServerState>(
  (ref) => TcpServer(),
);
