import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

// ─── TcpClient StateNotifier (WebSocket based) ───────────────────────────────

class TcpClient extends StateNotifier<TcpClientState> {
  TcpClient() : super(const TcpClientState());

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
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

  /// Initiates a WebSocket connection to the host at [ip]:[port] and transmits
  /// the initial HANDSHAKE packet.
  /// Returns `true` on successful handshake, `false` on failure/timeout.
  Future<bool> connect(
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

    return await _attemptConnection();
  }

  Future<bool> _attemptConnection() async {
    if (_userExplicitlyDisconnected) return false;

    final isInitial = state.status == TcpClientStatus.disconnected;
    _updateStatus(isInitial ? TcpClientStatus.connecting : TcpClientStatus.reconnecting);

    try {
      _closeSocket();

      // Normalize host: strip schemes, path, and port if user passed a full URL
      var host = _cachedIp!.trim();
      if (host.startsWith('http://')) host = host.substring(7);
      if (host.startsWith('https://')) host = host.substring(8);
      if (host.startsWith('ws://')) host = host.substring(5);
      if (host.startsWith('wss://')) host = host.substring(6);
      if (host.contains('/')) host = host.substring(0, host.indexOf('/'));
      if (host.contains(':')) host = host.substring(0, host.indexOf(':'));

      final port = _cachedPort ?? AppConstants.defaultPort;
      final wsUri = Uri.parse('ws://$host:$port/ws');

      _channel = WebSocketChannel.connect(wsUri);

      // Wait for WebSocket handshake to be ready with a 4 second timeout
      await _channel!.ready.timeout(const Duration(seconds: 4));

      _buffer.clear();
      _updateStatus(TcpClientStatus.connected);

      // Listen for incoming discrete WebSocket message frames
      _subscription = _channel!.stream.listen(
        (data) => _handleData(data.toString()),
        onDone: _onSocketClosed,
        onError: (e) => _onSocketClosed(error: e.toString()),
        cancelOnError: false,
      );

      // Transmit HANDSHAKE immediately upon WebSocket connection
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
      return true;
    } catch (e) {
      _onSocketClosed(error: 'Host unreachable or connection timed out.');
      return false;
    }
  }

  // ─── Incoming Data Processing ─────────────────────────────────────────────

  void _handleData(String data) {
    // In WebSocket frames, data may be a complete JSON string or multiple newline-separated messages
    if (data.contains('\n')) {
      final lines = data.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          _processLine(trimmed);
        }
      }
    } else {
      final trimmed = data.trim();
      if (trimmed.isNotEmpty) {
        _processLine(trimmed);
      }
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

      // Notify game listener of match events (start, move, sync, takeback, etc.)
      onMessageReceived?.call(map);
    } catch (_) {
      // Ignore malformed payloads
    }
  }

  // ─── Heartbeat ────────────────────────────────────────────────────────────

  void _startPingCycle() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConstants.pingInterval, (_) {
      if (state.isConnected) {
        send(SyncProtocol.ping());

        // Watchdog: If no PONG response in 5 seconds, consider connection lost
        _pongWatchdog?.cancel();
        _pongWatchdog = Timer(const Duration(seconds: 5), () {
          _onSocketClosed(error: 'Heartbeat timeout');
        });
      }
    });
  }

  // ─── Outgoing ─────────────────────────────────────────────────────────────

  /// Sends a message over the active WebSocket channel.
  bool send(String message) {
    if (_channel == null) return false;
    try {
      _channel!.sink.add(message);
      return true;
    } catch (_) {
      _onSocketClosed();
      return false;
    }
  }

  // ─── Auto-Reconnect & Teardown ────────────────────────────────────────────

  void _onSocketClosed({String? error}) {
    _closeSocket();

    if (_userExplicitlyDisconnected) {
      _updateStatus(TcpClientStatus.disconnected, error: error);
      return;
    }

    _updateStatus(TcpClientStatus.reconnecting, error: error);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(AppConstants.reconnectInterval, () {
      if (!_userExplicitlyDisconnected && _cachedIp != null) {
        _attemptConnection();
      }
    });
  }

  void _updateStatus(TcpClientStatus newStatus, {String? error}) {
    state = state.copyWith(
      status: newStatus,
      hostIp: _cachedIp,
      hostPort: _cachedPort,
      errorMessage: error,
    );
    onStatusChanged?.call(newStatus);
  }

  void _closeSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongWatchdog?.cancel();
    _pongWatchdog = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
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
