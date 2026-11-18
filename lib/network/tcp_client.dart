import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'sync_protocol.dart';

// ─── Client connection status ────────────────────────────────────────────────

enum TcpClientStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class TcpClientState {
  final TcpClientStatus status;
  final String? hostIp;
  final int? hostPort;
  final String? errorMessage;

  const TcpClientState({
    this.status = TcpClientStatus.disconnected,
    this.hostIp,
    this.hostPort,
    this.errorMessage,
  });

  bool get isConnected => status == TcpClientStatus.connected;

  TcpClientState copyWith({
    TcpClientStatus? status,
    String? hostIp,
    int? hostPort,
    String? errorMessage,
  }) {
    return TcpClientState(
      status: status ?? this.status,
      hostIp: hostIp ?? this.hostIp,
      hostPort: hostPort ?? this.hostPort,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ─── Callbacks ───────────────────────────────────────────────────────────────

typedef ClientMessageCallback = void Function(Map<String, dynamic> message);
typedef ClientStatusCallback = void Function(TcpClientStatus status);

// ─── TcpClient StateNotifier ─────────────────────────────────────────────────

class TcpClient extends StateNotifier<TcpClientState> {
  TcpClient() : super(const TcpClientState());

  Socket? _socket;
  final StringBuffer _buffer = StringBuffer();

  // Cached credentials for auto-reconnect
  String? _cachedIp;
  int? _cachedPort;
  String? _cachedPlayerId;
  String? _cachedName;
  String? _cachedRole;
  String? _cachedAvatarIcon;
  int? _cachedAvatarColor;

  bool _userExplicitlyDisconnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _pongWatchdog;

  /// External callback triggered when a parsed JSON message arrives
  ClientMessageCallback? onMessageReceived;

  /// External callback triggered when connection status changes
  ClientStatusCallback? onStatusChanged;

  // ─── Connect ─────────────────────────────────────────────────────────────

  /// Initiates a connection to the host at [ip]:[port] and transmits the
  /// initial HANDSHAKE packet.
  Future<void> connect(
    String ip,
    int port, {
    required String playerId,
    required String name,
    required String role,
    String? avatarIcon,
    int? avatarColor,
  }) async {
    _userExplicitlyDisconnected = false;
    _cachedIp = ip;
    _cachedPort = port;
    _cachedPlayerId = playerId;
    _cachedName = name;
    _cachedRole = role;
    _cachedAvatarIcon = avatarIcon;
    _cachedAvatarColor = avatarColor;

    await _attemptConnection();
  }

  Future<void> _attemptConnection() async {
    if (_userExplicitlyDisconnected) return;

    final isInitial = state.status == TcpClientStatus.disconnected;
    _updateStatus(isInitial ? TcpClientStatus.connecting : TcpClientStatus.reconnecting);

    try {
      _closeSocket();
      _socket = await Socket.connect(
        _cachedIp!,
        _cachedPort ?? AppConstants.tcpPort,
        timeout: const Duration(seconds: 4),
      );

      _buffer.clear();
      _updateStatus(TcpClientStatus.connected);

      // Listen for incoming newline-delimited chunks
      _socket!.cast<List<int>>().transform(utf8.decoder).listen(
        _handleDataChunk,
        onDone: _onSocketClosed,
        onError: (e) => _onSocketClosed(),
        cancelOnError: false,
      );

      // Send initial HANDSHAKE immediately upon socket connection
      final handshakePayload = SyncProtocol.handshake(
        playerId: _cachedPlayerId ?? 'unknown',
        name: _cachedName ?? 'Player',
        role: _cachedRole ?? 'player',
        avatarIcon: _cachedAvatarIcon,
        avatarColor: _cachedAvatarColor,
      );
      send(handshakePayload);

      // Start 2-second PING heartbeat cycle
      _startPingCycle();
    } catch (e) {
      _onSocketClosed();
    }
  }

  // ─── Incoming Data Processing ─────────────────────────────────────────────

  void _handleDataChunk(String chunk) {
    _buffer.write(chunk);
    final raw = _buffer.toString();
    final lines = raw.split('\n');

    _buffer.clear();
    // Process all complete lines (ending before the last newline)
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        _processLine(line);
      }
    }

    // Keep incomplete segment in buffer
    if (lines.last.isNotEmpty) {
      _buffer.write(lines.last);
    }
  }

  void _processLine(String line) {
    try {
      final map = SyncProtocol.decode(line);
      final type = SyncProtocol.normalizeType(map['type'] as String?);

      if (type == SyncProtocol.typePing) {
        // Automatically respond with PONG
        send(SyncProtocol.pong());
        return;
      }

      if (type == SyncProtocol.typePong) {
        // Reset watchdog
        _pongWatchdog?.cancel();
        _pongWatchdog = null;
        return;
      }

      // Notify game listener of game messages (start, move, sync, takeback, etc.)
      onMessageReceived?.call(map);
    } catch (_) {
      // Ignore malformed lines
    }
  }

  // ─── Heartbeat ────────────────────────────────────────────────────────────

  void _startPingCycle() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConstants.pingInterval, (_) {
      if (state.isConnected) {
        send(SyncProtocol.ping());

        // Watchdog: If no response in 4 seconds, mark connection broken
        _pongWatchdog?.cancel();
        _pongWatchdog = Timer(const Duration(seconds: 4), () {
          _onSocketClosed();
        });
      }
    });
  }

  // ─── Outgoing ─────────────────────────────────────────────────────────────

  /// Sends a newline-delimited message over the active socket.
  bool send(String message) {
    if (_socket == null) return false;
    try {
      final formatted = message.endsWith('\n') ? message : '$message\n';
      _socket!.write(formatted);
      return true;
    } catch (_) {
      _onSocketClosed();
      return false;
    }
  }

  // ─── Auto-Reconnect & Teardown ────────────────────────────────────────────

  void _onSocketClosed() {
    _closeSocket();

    if (_userExplicitlyDisconnected) {
      _updateStatus(TcpClientStatus.disconnected);
      return;
    }

    // If already reconnecting or disconnected, schedule auto-reconnect retry every 1 second
    _updateStatus(TcpClientStatus.reconnecting);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(AppConstants.reconnectInterval, () {
      if (!_userExplicitlyDisconnected && _cachedIp != null) {
        _attemptConnection();
      }
    });
  }

  void _updateStatus(TcpClientStatus newStatus) {
    state = state.copyWith(
      status: newStatus,
      hostIp: _cachedIp,
      hostPort: _cachedPort,
    );
    onStatusChanged?.call(newStatus);
  }

  void _closeSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongWatchdog?.cancel();
    _pongWatchdog = null;

    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
  }

  /// Explicitly disconnects and halts the auto-reconnect loop.
  Future<void> disconnect() async {
    _userExplicitlyDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeSocket();
    _updateStatus(TcpClientStatus.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

// ─── Riverpod provider ───────────────────────────────────────────────────────

final tcpClientProvider = StateNotifierProvider<TcpClient, TcpClientState>(
  (ref) => TcpClient(),
);
