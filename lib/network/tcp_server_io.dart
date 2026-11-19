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
    final uriPath = request.uri.path == '/' ? '/index.html' : request.uri.path;

    // 1. Check if Flutter Web bundle (build/web) exists on disk
    final buildWebDir = Directory('build/web');
    if (buildWebDir.existsSync()) {
      final safePath = uriPath.replaceAll('..', '');
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

    // 2. Fallback: Serve lightweight responsive mobile web client
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
    } else if (lower.endsWith('.svg')) {
      response.headers.contentType = ContentType('image', 'svg+xml');
    } else if (lower.endsWith('.ico')) {
      response.headers.contentType = ContentType('image', 'x-icon');
    } else {
      response.headers.contentType = ContentType.binary;
    }
  }

  String _generateFallbackHtmlClient() {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Knightfall Chess - Local Arena</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: #0E141C;
      color: #F1FFEF;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: flex-start;
      padding: 12px;
      overflow-x: hidden;
    }
    .container {
      width: 100%;
      max-width: 440px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .view { display: none; width: 100%; }
    .view.active { display: flex; flex-direction: column; gap: 10px; }

    /* Header */
    .top-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 12px;
      background: #161C24;
      border: 1px solid #242A33;
      border-radius: 12px;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 8px;
      font-weight: 800;
      font-size: 14px;
      letter-spacing: 0.5px;
      color: #F1FFEF;
    }
    .brand-icon {
      width: 26px;
      height: 26px;
      background: #090F16;
      border: 1px solid #00FF88;
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #00FF88;
      font-size: 16px;
    }
    .lan-pill {
      display: flex;
      align-items: center;
      gap: 5px;
      font-size: 10px;
      font-weight: 600;
      color: #00FF88;
      background: rgba(0,255,136,0.12);
      border: 1px solid rgba(0,255,136,0.3);
      padding: 3px 8px;
      border-radius: 12px;
    }
    .pulse-dot {
      width: 6px;
      height: 6px;
      background: #00FF88;
      border-radius: 50%;
      animation: pulse 1.6s infinite;
    }
    @keyframes pulse {
      0% { opacity: 0.4; transform: scale(0.9); }
      50% { opacity: 1; transform: scale(1.15); }
      100% { opacity: 0.4; transform: scale(0.9); }
    }

    /* Cards */
    .card {
      background: #161C24;
      border: 1px solid #242A33;
      border-radius: 14px;
      padding: 16px;
      box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    }
    .badge {
      display: inline-block;
      background: rgba(0, 255, 136, 0.15);
      color: #00FF88;
      border: 1px solid rgba(0, 255, 136, 0.4);
      padding: 3px 10px;
      border-radius: 20px;
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 0.5px;
      margin-bottom: 8px;
    }
    .badge.gold {
      background: rgba(255, 219, 60, 0.15);
      color: #FFDB3C;
      border-color: rgba(255, 219, 60, 0.4);
    }

    /* Player Banners */
    .player-banner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: #161C24;
      border: 1px solid #242A33;
      border-radius: 12px;
      padding: 8px 12px;
    }
    .player-info {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .player-avatar {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      background: #242A33;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 16px;
    }
    .player-name {
      font-size: 13px;
      font-weight: 700;
      color: #F1FFEF;
    }
    .player-meta {
      font-size: 10px;
      color: #8C8C9A;
    }
    .clock-box {
      font-family: 'SF Mono', Monaco, Consolas, monospace;
      font-size: 16px;
      font-weight: 800;
      letter-spacing: 0.5px;
      padding: 4px 10px;
      border-radius: 6px;
      background: #090F16;
      border: 1px solid #242A33;
      color: #F1FFEF;
    }
    .clock-box.active {
      color: #00FF88;
      border-color: #00FF88;
      box-shadow: 0 0 10px rgba(0,255,136,0.3);
    }
    .clock-box.active-turn-black {
      color: #FFDB3C;
      border-color: #FFDB3C;
      box-shadow: 0 0 10px rgba(255,219,60,0.3);
    }

    /* Chessboard Frame */
    .board-frame {
      background: #090F16;
      border: 1px solid #242A33;
      border-radius: 14px;
      padding: 6px;
      box-shadow: 0 12px 32px rgba(0,0,0,0.6);
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .chessboard {
      width: 100%;
      aspect-ratio: 1 / 1;
      display: grid;
      grid-template-columns: repeat(8, 1fr);
      grid-template-rows: repeat(8, 1fr);
      border-radius: 8px;
      overflow: hidden;
      user-select: none;
      touch-action: manipulation;
    }
    .sq {
      position: relative;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 34px;
      cursor: pointer;
      transition: background 0.12s;
    }
    .sq.light { background: #333C4A; }
    .sq.dark { background: #1C232E; }
    .sq.last-from, .sq.last-to { background: rgba(255, 219, 60, 0.38) !important; }
    .sq.selected {
      outline: 2px solid #00FF88;
      outline-offset: -2px;
      background: rgba(0, 255, 136, 0.28) !important;
      z-index: 2;
    }
    .sq.in-check {
      background: rgba(255, 23, 68, 0.6) !important;
      box-shadow: inset 0 0 12px #FF1744;
      animation: pulse-red 1s infinite alternate;
    }
    @keyframes pulse-red {
      from { box-shadow: inset 0 0 6px #FF1744; }
      to { box-shadow: inset 0 0 16px #FF1744; }
    }
    .piece {
      font-size: 32px;
      line-height: 1;
      user-select: none;
      pointer-events: none;
      filter: drop-shadow(0 2px 3px rgba(0,0,0,0.7));
    }
    .piece.w {
      color: #FFFFFF;
      text-shadow: 0 0 2px #000, 0 1px 3px rgba(255,255,255,0.4);
    }
    .piece.b {
      color: #0E141C;
      text-shadow: 0 0 2px #FFF, 0 0 6px #00FF88;
    }

    /* Move notation ticker */
    .ticker-bar {
      height: 28px;
      background: #090F16;
      border: 1px solid #242A33;
      border-radius: 8px;
      display: flex;
      align-items: center;
      padding: 0 10px;
      font-family: monospace;
      font-size: 11px;
      color: #8C8C9A;
      overflow-x: auto;
      white-space: nowrap;
    }

    /* Tactical Action Buttons */
    .btn-row {
      display: flex;
      gap: 8px;
      width: 100%;
    }
    .btn {
      flex: 1;
      background: #161C24;
      border: 1px solid #242A33;
      color: #F1FFEF;
      font-weight: 700;
      font-size: 12px;
      padding: 10px;
      border-radius: 10px;
      cursor: pointer;
      text-align: center;
      transition: all 0.2s;
    }
    .btn:hover { background: #222935; border-color: #00FF88; }
    .btn.primary {
      background: #00FF88;
      color: #0E141C;
      border-color: #00FF88;
    }
    .btn.primary:hover { background: #39FF7E; }

    /* Disconnect Alert */
    .disconnect-banner {
      display: none;
      background: #FF1744;
      color: #FFFFFF;
      padding: 8px 14px;
      border-radius: 10px;
      font-size: 12px;
      font-weight: 700;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }
    .retry-btn {
      background: #FFFFFF;
      color: #FF1744;
      border: none;
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 800;
      cursor: pointer;
    }

    /* Waiting room roster */
    .roster-list {
      display: flex;
      flex-direction: column;
      gap: 6px;
      margin-top: 10px;
      text-align: left;
    }
    .roster-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: #090F16;
      border: 1px solid #242A33;
      padding: 8px 12px;
      border-radius: 8px;
      font-size: 12px;
    }
  </style>
</head>
<body>
  <div class="container">

    <!-- Top Status Banner -->
    <div class="top-bar">
      <div class="brand">
        <div class="brand-icon">♞</div>
        <span>KNIGHTFALL CHESS</span>
      </div>
      <div class="lan-pill">
        <div class="pulse-dot"></div>
        <span id="header-status">WEBSOCKET P2P</span>
      </div>
    </div>

    <!-- Disconnect Banner -->
    <div id="disconnect-banner" class="disconnect-banner">
      <span>⚠️ Connection to host lost. Reconnecting...</span>
      <button onclick="connectWs()" class="retry-btn">Reconnect</button>
    </div>

    <!-- VIEW 1: CONNECTING -->
    <div id="view-connecting" class="view active">
      <div class="card" style="text-align: center; padding: 32px 20px;">
        <div class="badge">LIVE HOTSPOT HOST</div>
        <h1 style="font-size: 18px; margin: 10px 0 6px;">Connecting to Match...</h1>
        <p style="font-size: 12px; color: #8C8C9A; margin-bottom: 20px;">
          Establishing WebSocket connection to Host at <span id="conn-host">...</span>
        </p>
        <div class="pulse-dot" style="width: 14px; height: 14px; margin: 0 auto 20px;"></div>
        <button class="btn" onclick="connectWs()">Retry Connection</button>
      </div>
    </div>

    <!-- VIEW 2: WAITING ROOM -->
    <div id="view-waiting" class="view">
      <div class="card">
        <div class="badge gold">WAITING ROOM</div>
        <h2 style="font-size: 17px; margin-bottom: 4px;" id="waiting-room-title">Host Room</h2>
        <p style="font-size: 12px; color: #8C8C9A;" id="waiting-room-subtitle">Standard Duel • 5 min</p>

        <div style="margin: 16px 0 8px; font-size: 11px; font-weight: 700; color: #00FF88;">
          CONNECTED ROSTER
        </div>
        <div class="roster-list" id="waiting-roster">
          <!-- Populated dynamically via room_state -->
        </div>

        <div style="background: #090F16; border: 1px dashed #242A33; border-radius: 10px; padding: 14px; margin-top: 16px; text-align: center;">
          <div class="pulse-dot" style="margin: 0 auto 8px;"></div>
          <div style="font-size: 12px; font-weight: 700; color: #00FF88;">Waiting for Host to start match...</div>
          <div style="font-size: 10.5px; color: #8C8C9A; margin-top: 4px;">The game will automatically begin when the host launches.</div>
        </div>
      </div>
    </div>

    <!-- VIEW 3: ACTIVE MATCH -->
    <div id="view-match" class="view">

      <!-- Opponent Banner -->
      <div class="player-banner">
        <div class="player-info">
          <div class="player-avatar">♟</div>
          <div>
            <div class="player-name" id="opponent-name">Alex_V</div>
            <div class="player-meta" id="opponent-meta">Host • 1790 GM</div>
          </div>
        </div>
        <div class="clock-box" id="opponent-clock">05:00.0</div>
      </div>

      <!-- Chess Arena Frame -->
      <div class="board-frame">
        <div class="chessboard" id="board">
          <!-- 64 squares rendered dynamically from FEN -->
        </div>
      </div>

      <!-- Player Banner -->
      <div class="player-banner">
        <div class="player-info">
          <div class="player-avatar" style="border: 1px solid #00FF88;">♟</div>
          <div>
            <div class="player-name" id="player-name">Safari_Guest</div>
            <div class="player-meta" id="player-meta">Player 2 • Connected</div>
          </div>
        </div>
        <div class="clock-box active" id="player-clock">05:00.0</div>
      </div>

      <!-- Micro Notation Ticker -->
      <div class="ticker-bar" id="ticker-bar">
        1. e4 e5   2. Nf3 Nc6   3. Bb5 ...
      </div>

      <!-- Action Row -->
      <div class="btn-row">
        <button class="btn" onclick="flipBoard()">⇄ Flip</button>
        <button class="btn" onclick="offerDraw()">🤝 Draw</button>
        <button class="btn" style="color: #FF6B81;" onclick="resignGame()">⚐ Resign</button>
      </div>

    </div>

  </div>

  <script>
    // State
    let ws = null;
    let myPlayerId = 'web_' + Math.random().toString(36).substring(2, 9);
    let myRole = 'player';
    let myColor = 'black'; // default guest side
    let isFlipped = false;
    let hostName = 'Host';
    let currentFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    let whiteTimeMs = 300000;
    let blackTimeMs = 300000;
    let activeTurn = 'white';
    let lastMoveFrom = null;
    let lastMoveTo = null;
    let checkSquare = null;
    let selectedSquare = null;
    let isGameOver = false;
    let clockTimer = null;
    let moveList = [];

    const GLYPHS = {
      'P': '♙', 'N': '♘', 'B': '♗', 'R': '♖', 'Q': '♕', 'K': '♔',
      'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚'
    };

    function showView(viewId) {
      document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
      const target = document.getElementById(viewId);
      if (target) target.classList.add('active');
    }

    function connectWs() {
      const connHostEl = document.getElementById('conn-host');
      if (connHostEl) connHostEl.innerText = location.host;

      const wsProto = location.protocol === 'https:' ? 'wss:' : 'ws:';
      const wsUrl = wsProto + '//' + location.host + '/ws';

      try {
        if (ws) {
          ws.onclose = null;
          ws.onerror = null;
          ws.close();
        }
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
          document.getElementById('disconnect-banner').style.display = 'none';
          document.getElementById('header-status').innerText = 'CONNECTED';
          ws.send(JSON.stringify({
            type: 'handshake',
            playerId: myPlayerId,
            name: 'Web_Guest',
            role: myRole
          }));
        };

        ws.onmessage = (e) => {
          try {
            const raw = e.data.trim();
            if (!raw) return;
            // Handle multiple newline-separated packets if grouped
            const lines = raw.split('\\n');
            for (const line of lines) {
              if (line.trim()) handlePacket(JSON.parse(line.trim()));
            }
          } catch(err) {
            console.error('Packet parse error:', err);
          }
        };

        ws.onclose = () => {
          document.getElementById('disconnect-banner').style.display = 'flex';
          document.getElementById('header-status').innerText = 'DISCONNECTED';
          setTimeout(connectWs, 2000);
        };

        ws.onerror = () => {
          document.getElementById('disconnect-banner').style.display = 'flex';
        };

      } catch(e) {
        console.error('WebSocket init error:', e);
        setTimeout(connectWs, 2000);
      }
    }

    function handlePacket(msg) {
      const type = (msg.type || '').toLowerCase().replace('-', '_');

      // 1. Silent Heartbeat: Answer ping with pong and ignore in UI
      if (type === 'ping') {
        if (ws && ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'pong' }));
        }
        return;
      }
      if (type === 'pong') {
        return;
      }

      // 2. Room State (Waiting Room)
      if (type === 'room_state') {
        hostName = msg.hostName || 'Host';
        document.getElementById('waiting-room-title').innerText = hostName + "'s Match Room";
        document.getElementById('waiting-room-subtitle').innerText =
          (msg.gameMode || 'Standard').toUpperCase() + ' • ' + Math.round((msg.timeControl || 300) / 60) + ' min';

        const rosterEl = document.getElementById('waiting-roster');
        rosterEl.innerHTML = '';
        const players = msg.players || [];
        players.forEach(p => {
          const item = document.createElement('div');
          item.className = 'roster-item';
          item.innerHTML = '<span>' + (p.isHost ? '👑 ' : '👤 ') + p.name + '</span>' +
            '<span class="badge" style="margin:0;">' + (p.role || 'player').toUpperCase() + '</span>';
          rosterEl.appendChild(item);
        });

        if (!document.getElementById('view-match').classList.contains('active')) {
          showView('view-waiting');
        }
        return;
      }

      // 3. Match Start
      if (type === 'start' || type === 'gamestart' || type === 'game_start') {
        if (msg.blackId === myPlayerId) {
          myColor = 'black';
          isFlipped = true;
        } else if (msg.whiteId === myPlayerId) {
          myColor = 'white';
          isFlipped = false;
        } else {
          myRole = 'spectator';
        }

        currentFen = msg.fen || 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
        const tc = msg.timeControl || 300;
        whiteTimeMs = tc * 1000;
        blackTimeMs = tc * 1000;
        moveList = [];
        isGameOver = false;

        document.getElementById('opponent-name').innerText =
          myColor === 'white' ? (msg.blackName || 'Player 2') : (msg.whiteName || hostName);
        document.getElementById('player-name').innerText =
          myColor === 'white' ? (msg.whiteName || hostName) : (msg.blackName || 'Web_Guest');

        showView('view-match');
        startClockTimer();
        renderBoard();
        return;
      }

      // 4. Move
      if (type === 'move') {
        currentFen = msg.fen || currentFen;
        lastMoveFrom = msg.from;
        lastMoveTo = msg.to;
        if (msg.whiteTimeMs != null) whiteTimeMs = msg.whiteTimeMs;
        if (msg.blackTimeMs != null) blackTimeMs = msg.blackTimeMs;
        activeTurn = (currentFen.split(' ')[1] === 'w') ? 'white' : 'black';

        playMoveSound();
        if (msg.from && msg.to) {
          moveList.push(msg.from + '-' + msg.to);
          updateTicker();
        }
        renderBoard();
        return;
      }

      // 5. Sync State (Spectator / Reconnect)
      if (type === 'sync') {
        currentFen = msg.fen;
        if (msg.moveHistory) moveList = msg.moveHistory;
        if (msg.whiteTimeMs != null) whiteTimeMs = msg.whiteTimeMs;
        if (msg.blackTimeMs != null) blackTimeMs = msg.blackTimeMs;
        activeTurn = (currentFen.split(' ')[1] === 'w') ? 'white' : 'black';

        showView('view-match');
        startClockTimer();
        renderBoard();
        updateTicker();
        return;
      }

      // 6. Game Over
      if (type === 'game_over' || type === 'gameover') {
        isGameOver = true;
        clearInterval(clockTimer);
        alert('Match Ended: ' + (msg.reason || 'Game Concluded') + (msg.winnerId ? ' (Winner: ' + msg.winnerId + ')' : ''));
        return;
      }
    }

    // ─── Chessboard Rendering ───────────────────────────────────────────────

    function getBoardMap(fen) {
      const placement = fen.split(' ')[0];
      const rows = placement.split('/');
      const map = {};
      for (let r = 0; r < 8; r++) {
        const rowStr = rows[r];
        let c = 0;
        for (let i = 0; i < rowStr.length; i++) {
          const ch = rowStr[i];
          const empty = parseInt(ch);
          if (!isNaN(empty)) {
            c += empty;
          } else {
            const sq = String.fromCharCode(97 + c) + (8 - r);
            map[sq] = {
              char: ch,
              color: ch === ch.toUpperCase() ? 'white' : 'black',
              glyph: GLYPHS[ch] || ch
            };
            c++;
          }
        }
      }
      return map;
    }

    function renderBoard() {
      const boardEl = document.getElementById('board');
      if (!boardEl) return;
      boardEl.innerHTML = '';

      const boardMap = getBoardMap(currentFen);
      activeTurn = (currentFen.split(' ')[1] === 'w') ? 'white' : 'black';

      // Find King in check
      checkSquare = null;

      for (let r = 0; r < 8; r++) {
        for (let c = 0; c < 8; c++) {
          const row = isFlipped ? (7 - r) : r;
          const col = isFlipped ? (7 - c) : c;
          const sq = String.fromCharCode(97 + col) + (8 - row);
          const isLight = (row + col) % 2 === 0;

          const sqEl = document.createElement('div');
          sqEl.className = 'sq ' + (isLight ? 'light' : 'dark');
          sqEl.dataset.sq = sq;

          if (sq === lastMoveFrom) sqEl.classList.add('last-from');
          if (sq === lastMoveTo) sqEl.classList.add('last-to');
          if (sq === selectedSquare) sqEl.classList.add('selected');
          if (sq === checkSquare) sqEl.classList.add('in-check');

          const piece = boardMap[sq];
          if (piece) {
            const pEl = document.createElement('span');
            pEl.className = 'piece ' + (piece.color === 'white' ? 'w' : 'b');
            pEl.innerText = piece.glyph;
            sqEl.appendChild(pEl);
          }

          sqEl.onclick = () => onSquareClicked(sq);
          boardEl.appendChild(sqEl);
        }
      }

      updateClockHighlight();
    }

    function onSquareClicked(sq) {
      if (isGameOver) return;
      if (myRole !== 'player') return;

      const boardMap = getBoardMap(currentFen);
      const piece = boardMap[sq];
      const isFriendly = piece && piece.color === myColor;

      if (!selectedSquare) {
        if (isFriendly && activeTurn === myColor) {
          selectedSquare = sq;
          renderBoard();
        }
      } else if (selectedSquare === sq) {
        selectedSquare = null;
        renderBoard();
      } else if (isFriendly) {
        selectedSquare = sq;
        renderBoard();
      } else {
        const from = selectedSquare;
        const to = sq;
        selectedSquare = null;
        sendMove(from, to);
      }
    }

    function sendMove(from, to) {
      if (!ws || ws.readyState !== WebSocket.OPEN) return;
      ws.send(JSON.stringify({
        type: 'move',
        from: from,
        to: to,
        whiteTimeMs: whiteTimeMs,
        blackTimeMs: blackTimeMs
      }));
      playMoveSound();
    }

    function flipBoard() {
      isFlipped = !isFlipped;
      renderBoard();
    }

    function offerDraw() {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'takeback_req', requesterId: myPlayerId }));
        alert('Draw/Takeback request sent to host.');
      }
    }

    function resignGame() {
      if (confirm('Are you sure you want to resign this match?')) {
        if (ws && ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'game_over', reason: 'resignation', winnerId: hostName }));
        }
      }
    }

    // ─── Clocks & Audio ─────────────────────────────────────────────────────

    function formatTime(ms) {
      if (ms <= 0) return '00:00.0';
      const totalSec = Math.floor(ms / 1000);
      const m = Math.floor(totalSec / 60);
      const s = totalSec % 60;
      const tenths = Math.floor((ms % 1000) / 100);
      return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0') + '.' + tenths;
    }

    function startClockTimer() {
      if (clockTimer) clearInterval(clockTimer);
      clockTimer = setInterval(() => {
        if (isGameOver) return;
        if (activeTurn === 'white') {
          whiteTimeMs = Math.max(0, whiteTimeMs - 100);
        } else {
          blackTimeMs = Math.max(0, blackTimeMs - 100);
        }
        updateClockDisplay();
      }, 100);
    }

    function updateClockDisplay() {
      const oppClock = document.getElementById('opponent-clock');
      const plyClock = document.getElementById('player-clock');
      if (oppClock && plyClock) {
        oppClock.innerText = formatTime(myColor === 'white' ? blackTimeMs : whiteTimeMs);
        plyClock.innerText = formatTime(myColor === 'white' ? whiteTimeMs : blackTimeMs);
      }
    }

    function updateClockHighlight() {
      const oppClock = document.getElementById('opponent-clock');
      const plyClock = document.getElementById('player-clock');
      if (!oppClock || !plyClock) return;

      oppClock.classList.remove('active', 'active-turn-black');
      plyClock.classList.remove('active', 'active-turn-black');

      const isMyTurn = (activeTurn === myColor);
      if (isMyTurn) {
        plyClock.classList.add('active');
      } else {
        oppClock.classList.add('active');
      }
    }

    function updateTicker() {
      const ticker = document.getElementById('ticker-bar');
      if (!ticker) return;
      if (moveList.length === 0) {
        ticker.innerText = 'Game started. Awaiting opening move...';
      } else {
        ticker.innerText = moveList.join('   ');
      }
    }

    function playMoveSound() {
      try {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtx) return;
        const ctx = new AudioCtx();
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.type = 'sine';
        osc.frequency.setValueAtTime(440, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(180, ctx.currentTime + 0.07);
        gain.gain.setValueAtTime(0.3, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.07);
        osc.start();
        osc.stop(ctx.currentTime + 0.07);
      } catch(e) {}
    }

    // Auto connect on page load
    window.onload = () => {
      connectWs();
    };
  </script>
</body>
</html>''';
  }

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
