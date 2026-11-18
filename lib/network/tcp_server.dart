import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'sync_protocol.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

enum ClientRole { player, spectator }

class ConnectedClient {
  final Socket socket;
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

// ─── State ────────────────────────────────────────────────────────────────────

class TcpServerState {
  final bool isRunning;
  final List<ConnectedClient> clients;

  const TcpServerState({this.isRunning = false, this.clients = const []});

  TcpServerState copyWith({bool? isRunning, List<ConnectedClient>? clients}) =>
      TcpServerState(
        isRunning: isRunning ?? this.isRunning,
        clients: clients ?? this.clients,
      );

  List<ConnectedClient> get players =>
      clients.where((c) => c.role == ClientRole.player).toList();

  List<ConnectedClient> get spectators =>
      clients.where((c) => c.role == ClientRole.spectator).toList();
}

// ─── StateNotifier ────────────────────────────────────────────────────────────

typedef MessageCallback = void Function(
    String playerId, Map<String, dynamic> message);
typedef DisconnectCallback = void Function(String playerId);

class TcpServer extends StateNotifier<TcpServerState> {
  TcpServer() : super(const TcpServerState());

  ServerSocket? _server;

  /// Called by the game logic layer when a message arrives.
  MessageCallback? onMessageReceived;

  /// Called when a client disconnects.
  DisconnectCallback? onClientDisconnected;

  /// Stored so we can send SYNC_STATE to reconnecting clients.
  /// Set by the game logic layer after every move.
  String Function()? buildSyncState;

  // Known player IDs for auto-reconnect detection
  final Set<String> _knownPlayerIds = {};
  // Per-client buffer for accumulating partial lines
  final Map<String, StringBuffer> _buffers = {};
  // Ping timers keyed by playerId
  final Map<String, Timer> _pingTimers = {};
  // Pong watchdog timers keyed by playerId
  final Map<String, Timer> _pongWatchdogs = {};

  // ─── Start / Stop ────────────────────────────────────────────────────────

  Future<void> start() async {
    if (state.isRunning) return;

    _server =
        await ServerSocket.bind(InternetAddress.anyIPv4, AppConstants.tcpPort);
    state = state.copyWith(isRunning: true);

    _server!.listen(
      _handleNewConnection,
      onError: (e) => _server?.close(),
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    for (final client in state.clients) {
      _cleanupClient(client.playerId);
      try {
        client.socket.destroy();
      } catch (_) {}
    }
    _server?.close();
    _server = null;
    state = const TcpServerState();
  }

  // ─── Connection handling ─────────────────────────────────────────────────

  void _handleNewConnection(Socket socket) {
    final buffer = StringBuffer();
    String? pendingPlayerId; // set once HANDSHAKE is parsed

    socket.cast<List<int>>().transform(utf8.decoder).listen(
      (chunk) {
        buffer.write(chunk);
        _processLines(buffer, (line) {
          if (pendingPlayerId == null) {
            // First message MUST be HANDSHAKE
            _handleHandshake(socket, line, (pid) {
              pendingPlayerId = pid;
              _buffers[pid] = StringBuffer();
            });
          } else {
            final pid = pendingPlayerId!;
            _buffers[pid]?.write(line);
            _routeMessage(pid, line);
          }
        });
      },
      onDone: () {
        if (pendingPlayerId != null) _handleDisconnect(pendingPlayerId!);
        try {
          socket.destroy();
        } catch (_) {}
      },
      onError: (e) {
        if (pendingPlayerId != null) _handleDisconnect(pendingPlayerId!);
        try {
          socket.destroy();
        } catch (_) {}
      },
      cancelOnError: false,
    );
  }

  /// Parses HANDSHAKE, registers client, and optionally replays SYNC_STATE.
  void _handleHandshake(
    Socket socket,
    String line,
    void Function(String pid) onRegistered,
  ) {
    try {
      final msg = SyncProtocol.decode(line);
      final type = SyncProtocol.normalizeType(msg['type'] as String?);
      if (type != SyncProtocol.typeHandshake) {
        socket.destroy();
        return;
      }

      final playerId = msg['playerId'] as String;
      final name = (msg['name'] as String?) ?? 'Unknown';
      final roleStr = (msg['role'] as String?) ?? 'spectator';

      // Detect reconnect: if playerId was previously seen and is currently disconnected
      final isReconnect = _knownPlayerIds.contains(playerId) &&
          !state.clients.any((c) => c.playerId == playerId);

      // Assign role: first 2 'player' handshakes are players, rest are spectators
      final ClientRole role;
      if (roleStr == 'player' && state.players.length < 2) {
        role = ClientRole.player;
      } else {
        role = ClientRole.spectator;
      }

      final client = ConnectedClient(
        socket: socket,
        playerId: playerId,
        name: name,
        role: role,
      );

      _knownPlayerIds.add(playerId);
      final updated = List<ConnectedClient>.from(state.clients)..add(client);
      state = state.copyWith(clients: updated);
      onRegistered(playerId);

      // Send SYNC_STATE to reconnecting / spectator clients
      if (isReconnect || role == ClientRole.spectator) {
        final syncMsg = buildSyncState?.call();
        if (syncMsg != null) {
          _sendToSocket(socket, syncMsg);
        }
      }

      // Start keepalive
      _startPingCycle(playerId);
    } catch (_) {
      socket.destroy();
    }
  }

  void _routeMessage(String playerId, String line) {
    try {
      final msg = SyncProtocol.decode(line);
      final type = SyncProtocol.normalizeType(msg['type'] as String?);
      if (type == SyncProtocol.typePong) {
        // Cancel watchdog — pong received in time
        _pongWatchdogs[playerId]?.cancel();
        _pongWatchdogs.remove(playerId);
        return;
      }
      if (type == SyncProtocol.typePing) {
        // Automatically respond to client ping with pong
        sendTo(playerId, SyncProtocol.pong());
        return;
      }
      onMessageReceived?.call(playerId, msg);
    } catch (_) {
      // Malformed message — ignore
    }
  }

  // ─── Keepalive ───────────────────────────────────────────────────────────

  void _startPingCycle(String playerId) {
    _pingTimers[playerId]?.cancel();
    _pingTimers[playerId] =
        Timer.periodic(AppConstants.pingInterval, (_) => _sendPing(playerId));
  }

  void _sendPing(String playerId) {
    final client = _clientById(playerId);
    if (client == null) return;
    _sendToSocket(client.socket, SyncProtocol.ping());

    // Watchdog: if no PONG within 5 s, treat as disconnected
    _pongWatchdogs[playerId]?.cancel();
    _pongWatchdogs[playerId] = Timer(const Duration(seconds: 5), () {
      _handleDisconnect(playerId);
    });
  }

  // ─── Outbound messaging ──────────────────────────────────────────────────

  /// Sends [message] to every connected client (players + spectators).
  void broadcast(String message) {
    for (final client in state.clients) {
      _sendToSocket(client.socket, message);
    }
  }

  /// Sends [message] only to the client with [playerId].
  void sendTo(String playerId, String message) {
    final client = _clientById(playerId);
    if (client != null) _sendToSocket(client.socket, message);
  }

  void _sendToSocket(Socket socket, String message) {
    try {
      socket.write(message.endsWith('\n') ? message : '$message\n');
    } catch (_) {}
  }

  // ─── Disconnect ──────────────────────────────────────────────────────────

  void _handleDisconnect(String playerId) {
    _cleanupClient(playerId);
    final updated =
        state.clients.where((c) => c.playerId != playerId).toList();
    state = state.copyWith(clients: updated);
    onClientDisconnected?.call(playerId);
  }

  void _cleanupClient(String playerId) {
    _pingTimers[playerId]?.cancel();
    _pingTimers.remove(playerId);
    _pongWatchdogs[playerId]?.cancel();
    _pongWatchdogs.remove(playerId);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  ConnectedClient? _clientById(String playerId) {
    try {
      return state.clients.firstWhere((c) => c.playerId == playerId);
    } catch (_) {
      return null;
    }
  }

  /// Splits [buffer] on newlines, calling [onLine] for each complete line.
  void _processLines(StringBuffer buffer, void Function(String) onLine) {
    final raw = buffer.toString();
    final lines = raw.split('\n');
    buffer.clear();
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) onLine('$line\n');
    }
    // Last segment may be incomplete — keep in buffer
    if (lines.last.isNotEmpty) buffer.write(lines.last);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ─── Riverpod provider ───────────────────────────────────────────────────────

final tcpServerProvider = StateNotifierProvider<TcpServer, TcpServerState>(
  (ref) => TcpServer(),
);
