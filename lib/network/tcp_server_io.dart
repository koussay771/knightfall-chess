import 'web_client_html.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'sync_protocol.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

enum ClientRole { player, spectator }

class ConnectedClient {
  final dynamic socket; // WebSocket (or Socket for legacy compat)
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
  final int port;
  final List<ConnectedClient> clients;

  const TcpServerState({
    this.isRunning = false,
    this.port = AppConstants.defaultPort,
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

  HttpServer? _httpServer;

  /// Returns the active bound port, or null if server is stopped.
  int? get actualPort => _httpServer?.port;

  /// Public read-only accessor for the current list of connected clients.
  List<ConnectedClient> get clients => state.clients;

  /// Called by the game logic layer when a message arrives.
  MessageCallback? onMessageReceived;

  /// Called when a client disconnects.
  DisconnectCallback? onClientDisconnected;

  /// Stored so we can send SYNC_STATE to reconnecting clients.
  String Function()? buildSyncState;

  /// Stored so we can broadcast ROOM_STATE to waiting room clients.
  String Function()? buildRoomState;

  final Set<String> _knownPlayerIds = {};
  final Map<String, Timer> _pingTimers = {};
  final Map<String, Timer> _pongWatchdogs = {};

  // ─── Start / Stop ────────────────────────────────────────────────────────

  /// Starts the embedded HTTP & WebSocket server on 0.0.0.0.
  /// Binds to [port] (defaulting to [AppConstants.defaultPort] 8080).
  Future<int> start({int? port}) async {
    if (state.isRunning && _httpServer != null) return _httpServer!.port;

    int bindPort = port ?? AppConstants.defaultPort;

    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, bindPort);
    } catch (e) {
      // If default port is taken and no explicit port was forced, try fallbacks
      if (port == null) {
        for (final fallback in [8081, 8082, 8888, 4545]) {
          try {
            _httpServer =
                await HttpServer.bind(InternetAddress.anyIPv4, fallback);
            bindPort = fallback;
            break;
          } catch (_) {}
        }
      }
      if (_httpServer == null) rethrow;
    }

    state = state.copyWith(isRunning: true, port: _httpServer!.port);

    _httpServer!.listen(
      _handleRequest,
      onError: (e) => stop(),
      cancelOnError: false,
    );

    return _httpServer!.port;
  }

  Future<void> stop() async {
    for (final client in state.clients) {
      _cleanupClient(client.playerId);
      _closeClientSocket(client.socket);
    }
    await _httpServer?.close(force: true);
    _httpServer = null;
    state = const TcpServerState();
  }

  void _closeClientSocket(dynamic socket) {
    try {
      if (socket is WebSocket) {
        socket.close();
      } else if (socket is Socket) {
        socket.destroy();
      }
    } catch (_) {}
  }

  // ─── Request Routing ─────────────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest request) async {
    // Add permissive CORS headers so web clients on any origin/port can connect
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers
        .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final webSocket = await WebSocketTransformer.upgrade(request);
        _handleNewWebSocketConnection(webSocket);
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      }
    } else if (request.method == 'GET') {
      await _serveStaticOrFallback(request);
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
    }
  }

  // ─── Static Web Serving & Fallback ───────────────────────────────────────

  Future<void> _serveStaticOrFallback(HttpRequest request) async {
    request.response.headers.set(
        'Cache-Control', 'no-cache, no-store, must-revalidate, max-age=0');
    request.response.headers.set('Pragma', 'no-cache');
    request.response.headers.set('Expires', '0');

    final uriPath = request.uri.path == '/' ? '/index.html' : request.uri.path;
    final safePath = uriPath.replaceAll('..', '');

    // 1. Direct assets serving on disk (e.g. /assets/sound/..., /assets/piece/...)
    if (safePath.startsWith('/assets/')) {
      final assetFile = File(safePath.substring(1));
      if (assetFile.existsSync()) {
        _setMimeType(request.response, assetFile.path);
        await assetFile.openRead().pipe(request.response);
        return;
      }
    }

    // 2. Check if Flutter Web bundle (build/web) exists on disk
    final buildWebDir = Directory('build/web');
    if (buildWebDir.existsSync()) {
      final file = File('build/web$safePath');
      if (file.existsSync()) {
        _setMimeType(request.response, file.path);
        await file.openRead().pipe(request.response);
        return;
      }

      // If route not found on disk, fallback to index.html for SPA routing
      final indexFile = File('build/web/index.html');
      if (indexFile.existsSync()) {
        request.response.headers.contentType = ContentType.html;
        await indexFile.openRead().pipe(request.response);
        return;
      }
    }

    // 3. Fallback: Serve lightweight responsive mobile web client
    request.response.headers.contentType = ContentType.html;
    request.response.write(_generateFallbackHtmlClient());
    await request.response.close();
  }

  void _setMimeType(HttpResponse response, String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      response.headers.contentType = ContentType.html;
    } else if (lower.endsWith('.js') || lower.endsWith('.mjs')) {
      response.headers.contentType =
          ContentType('application', 'javascript', charset: 'utf-8');
    } else if (lower.endsWith('.json')) {
      response.headers.contentType = ContentType.json;
    } else if (lower.endsWith('.wasm')) {
      response.headers.contentType = ContentType('application', 'wasm');
    } else if (lower.endsWith('.css')) {
      response.headers.contentType = ContentType('text', 'css', charset: 'utf-8');
    } else if (lower.endsWith('.png')) {
      response.headers.contentType = ContentType('image', 'png');
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      response.headers.contentType = ContentType('image', 'jpeg');
    } else if (lower.endsWith('.webp')) {
      response.headers.contentType = ContentType('image', 'webp');
    } else if (lower.endsWith('.svg')) {
      response.headers.contentType = ContentType('image', 'svg+xml');
    } else if (lower.endsWith('.ico')) {
      response.headers.contentType = ContentType('image', 'x-icon');
    } else if (lower.endsWith('.mp3')) {
      response.headers.contentType = ContentType('audio', 'mpeg');
    } else if (lower.endsWith('.ogg')) {
      response.headers.contentType = ContentType('audio', 'ogg');
    } else if (lower.endsWith('.wav')) {
      response.headers.contentType = ContentType('audio', 'wav');
    } else if (lower.endsWith('.webm')) {
      response.headers.contentType = ContentType('audio', 'webm');
    } else {
      response.headers.contentType = ContentType.binary;
    }
  }

  String _generateFallbackHtmlClient() => generateFallbackHtmlClient();

  // ─── WebSocket Connection Handling ────────────────────────────────────────

  void _handleNewWebSocketConnection(WebSocket webSocket) {
    String? pendingPlayerId;

    webSocket.listen(
      (data) {
        final line = data.toString();
        // Parse newline-separated messages if batch sent, or single JSON string
        if (line.contains('\n')) {
          for (final segment in line.split('\n')) {
            final trimmed = segment.trim();
            if (trimmed.isNotEmpty) {
              _processInbound(webSocket, trimmed, (pid) => pendingPlayerId = pid,
                  pendingPlayerId);
            }
          }
        } else {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            _processInbound(webSocket, trimmed, (pid) => pendingPlayerId = pid,
                pendingPlayerId);
          }
        }
      },
      onDone: () {
        if (pendingPlayerId != null) _handleDisconnect(pendingPlayerId!);
        _closeClientSocket(webSocket);
      },
      onError: (e) {
        if (pendingPlayerId != null) _handleDisconnect(pendingPlayerId!);
        _closeClientSocket(webSocket);
      },
      cancelOnError: false,
    );
  }

  void _processInbound(WebSocket webSocket, String raw,
      void Function(String) setPid, String? currentPid) {
    if (currentPid == null) {
      _handleHandshake(webSocket, raw, (pid) {
        setPid(pid);
      });
    } else {
      _routeMessage(currentPid, raw);
    }
  }

  void _handleHandshake(
    dynamic socket,
    String line,
    void Function(String pid) onRegistered,
  ) {
    try {
      final msg = SyncProtocol.decode(line);
      final type = SyncProtocol.normalizeType(msg['type'] as String?);
      if (type != SyncProtocol.typeHandshake) {
        _closeClientSocket(socket);
        return;
      }

      final playerId = msg['playerId'] as String;
      final name = (msg['name'] as String?) ?? 'Guest';
      final roleStr = (msg['role'] as String?) ?? 'player';

      // Assign role: first 2 'player' handshakes are active players, rest spectators
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

      // Replay state to client:
      if (buildSyncState != null) {
        // Active match in progress: send SYNC_STATE
        final syncMsg = buildSyncState?.call();
        if (syncMsg != null) {
          _sendToSocket(socket, syncMsg);
        }
      } else if (buildRoomState != null) {
        // In waiting room: send current ROOM_STATE and broadcast updated room list
        final roomMsg = buildRoomState?.call();
        if (roomMsg != null) {
          _sendToSocket(socket, roomMsg);
          broadcast(roomMsg);
        }
      }

      _startPingCycle(playerId);
    } catch (_) {
      _closeClientSocket(socket);
    }
  }

  void _routeMessage(String playerId, String line) {
    try {
      final msg = SyncProtocol.decode(line);
      final type = SyncProtocol.normalizeType(msg['type'] as String?);
      if (type == SyncProtocol.typePong) {
        _pongWatchdogs[playerId]?.cancel();
        _pongWatchdogs.remove(playerId);
        return;
      }
      if (type == SyncProtocol.typePing) {
        sendTo(playerId, SyncProtocol.pong());
        return;
      }
      onMessageReceived?.call(playerId, msg);
    } catch (_) {
      // Ignore malformed payloads
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

    _pongWatchdogs[playerId]?.cancel();
    _pongWatchdogs[playerId] = Timer(const Duration(seconds: 5), () {
      _handleDisconnect(playerId);
    });
  }

  // ─── Outbound messaging ──────────────────────────────────────────────────

  /// Broadcasts [message] to all connected players and spectators.
  void broadcast(String message) {
    for (final client in state.clients) {
      _sendToSocket(client.socket, message);
    }
  }

  /// Sends [message] directly to client with [playerId].
  void sendTo(String playerId, String message) {
    final client = _clientById(playerId);
    if (client != null) _sendToSocket(client.socket, message);
  }

  void _sendToSocket(dynamic socket, String message) {
    try {
      if (socket is WebSocket) {
        socket.add(message);
      } else if (socket is Socket) {
        socket.write(message.endsWith('\n') ? message : '$message\n');
      }
    } catch (_) {}
  }

  // ─── Disconnect ──────────────────────────────────────────────────────────

  void _handleDisconnect(String playerId) {
    _cleanupClient(playerId);
    final updated =
        state.clients.where((c) => c.playerId != playerId).toList();
    state = state.copyWith(clients: updated);
    onClientDisconnected?.call(playerId);

    // If still in waiting room, broadcast updated client list to remaining clients
    if (buildRoomState != null && buildSyncState == null) {
      final roomMsg = buildRoomState?.call();
      if (roomMsg != null) broadcast(roomMsg);
    }
  }

  void _cleanupClient(String playerId) {
    _pingTimers[playerId]?.cancel();
    _pingTimers.remove(playerId);
    _pongWatchdogs[playerId]?.cancel();
    _pongWatchdogs.remove(playerId);
  }

  ConnectedClient? _clientById(String playerId) {
    try {
      return state.clients.firstWhere((c) => c.playerId == playerId);
    } catch (_) {
      return null;
    }
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
