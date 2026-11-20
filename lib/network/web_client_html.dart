/// Generates the complete embedded responsive HTML5/WebSocket web client
/// served by the local chess host HTTP server.
String generateFallbackHtmlClient() {
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
      border-radius: 20px;
    }
    .pulse-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #00FF88;
      box-shadow: 0 0 8px #00FF88;
      animation: pulse 1.5s infinite;
    }
    @keyframes pulse {
      0% { opacity: 0.4; }
      50% { opacity: 1; }
      100% { opacity: 0.4; }
    }

    /* Player / Opponent Banners */
    .player-banner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 12px;
      background: #161C24;
      border: 1px solid #242A33;
      border-radius: 10px;
    }
    .player-info {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .player-avatar {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      background: #090F16;
      border: 1px solid #2A3340;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
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
      font-family: monospace;
      font-size: 15px;
      font-weight: 700;
      background: #090F16;
      border: 1px solid #242A33;
      padding: 4px 10px;
      border-radius: 6px;
      color: #8C8C9A;
      letter-spacing: 0.5px;
    }
    .clock-box.active {
      color: #00FF88;
      border-color: #00FF88;
      box-shadow: 0 0 10px rgba(0, 255, 136, 0.2);
    }
    .clock-box.low-time {
      color: #FF1744;
      border-color: #FF1744;
      box-shadow: 0 0 10px rgba(255, 23, 68, 0.3);
    }

    /* History Preview Banner */
    #history-preview-banner {
      display: none;
      align-items: center;
      justify-content: space-between;
      background: #16202C;
      border: 1px solid #38BDF8;
      border-radius: 8px;
      padding: 6px 12px;
    }

    /* Chessboard Arena */
    .board-frame {
      width: 100%;
      background: #161C24;
      border: 1px solid #2A3340;
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
    .sq.last-from, .sq.last-to {
      background: rgba(255, 204, 2, 0.38) !important;
      outline: 1px solid rgba(255, 204, 2, 0.7);
      outline-offset: -1px;
    }
    .sq.selected {
      outline: 2px solid #00FF88;
      outline-offset: -2px;
      background: rgba(0, 255, 136, 0.28) !important;
      z-index: 2;
    }
    .sq.premove {
      background: rgba(56, 189, 248, 0.38) !important;
      outline: 2px solid #38BDF8;
      outline-offset: -2px;
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
      z-index: 3;
    }
    .piece.w {
      color: #FFFFFF;
      text-shadow: 0 0 2px #000, 0 1px 3px rgba(255,255,255,0.4);
    }
    .piece.b {
      color: #0E141C;
      text-shadow: 0 0 2px #FFF, 0 0 6px #00FF88;
    }

    /* Legal Move Path Indicators */
    .legal-dot {
      width: 14px;
      height: 14px;
      background: rgba(0, 255, 136, 0.55);
      border-radius: 50%;
      pointer-events: none;
      position: absolute;
      z-index: 4;
      box-shadow: 0 0 6px rgba(0, 255, 136, 0.4);
    }
    .legal-capture {
      width: 80%;
      height: 80%;
      border: 3px solid rgba(255, 59, 92, 0.8);
      border-radius: 50%;
      box-sizing: border-box;
      pointer-events: none;
      position: absolute;
      z-index: 4;
      box-shadow: 0 0 8px rgba(255, 59, 92, 0.4);
    }

    /* Move History Navigation Bar */
    .nav-row {
      display: flex;
      align-items: center;
      gap: 6px;
      width: 100%;
    }
    .nav-btn-group {
      display: flex;
      background: #161C24;
      border: 1px solid #242A33;
      border-radius: 8px;
      overflow: hidden;
    }
    .nav-btn {
      background: transparent;
      border: none;
      color: #8C8C9A;
      font-size: 13px;
      font-weight: 700;
      padding: 6px 10px;
      cursor: pointer;
      transition: all 0.15s;
    }
    .nav-btn:hover {
      background: rgba(0, 255, 136, 0.15);
      color: #00FF88;
    }
    .nav-btn:active {
      transform: scale(0.95);
    }
    .ticker-bar {
      height: 32px;
      background: #090F16;
      border: 1px solid #242A33;
      border-radius: 8px;
      display: flex;
      align-items: center;
      padding: 0 8px;
      font-family: monospace;
      font-size: 11px;
      color: #8C8C9A;
      overflow-x: auto;
      white-space: nowrap;
    }
    .move-chip {
      display: inline-block;
      padding: 3px 6px;
      border-radius: 4px;
      margin: 0 2px;
      cursor: pointer;
      color: #C0C8D2;
      transition: all 0.15s;
    }
    .move-chip:hover {
      background: rgba(255, 255, 255, 0.1);
      color: #FFF;
    }
    .move-chip.active {
      background: rgba(0, 255, 136, 0.25);
      color: #00FF88;
      font-weight: 700;
      outline: 1px solid #00FF88;
    }

    /* Action Buttons */
    .btn-row {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 6px;
    }
    .btn {
      background: #161C24;
      border: 1px solid #242A33;
      color: #F1FFEF;
      padding: 9px 4px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 4px;
      transition: all 0.15s;
    }
    .btn:active {
      transform: scale(0.97);
      background: #242A33;
    }
    .btn.primary {
      background: #00FF88;
      color: #0E141C;
      font-weight: 700;
      border-color: #00FF88;
    }

    /* Cards */
    .card {
      background: #161C24;
      border: 1px solid #242A33;
      border-radius: 12px;
      padding: 16px;
    }
    .roster-list {
      display: flex;
      flex-direction: column;
      gap: 6px;
      margin-top: 10px;
    }
    .roster-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 12px;
      background: #090F16;
      border: 1px solid #242A33;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
    }
    .badge {
      font-size: 9px;
      font-weight: 700;
      padding: 2px 6px;
      border-radius: 4px;
      background: rgba(0,255,136,0.15);
      color: #00FF88;
      border: 1px solid rgba(0,255,136,0.3);
    }
    .disconnect-banner {
      display: none;
      background: #FF1744;
      color: white;
      padding: 6px 12px;
      border-radius: 8px;
      font-size: 11px;
      font-weight: 700;
      align-items: center;
      justify-content: center;
      gap: 6px;
    }
  </style>
</head>
<body>

  <div class="container">

    <!-- TOP BAR -->
    <div class="top-bar">
      <div class="brand">
        <div class="brand-icon">⚔</div>
        <span>KNIGHTFALL CHESS</span>
      </div>
      <div class="lan-pill">
        <div class="pulse-dot"></div>
        <span id="header-status">LIVE WEBSOCKET</span>
      </div>
    </div>

    <!-- Disconnect Banner -->
    <div id="disconnect-banner" class="disconnect-banner">
      ⚠ Connection to Host Lost. Reconnecting...
    </div>

    <!-- VIEW 1: CONNECTING -->
    <div id="view-connecting" class="view active">
      <div class="card" style="text-align: center; padding: 32px 16px;">
        <div class="pulse-dot" style="margin: 0 auto 16px; width: 12px; height: 12px;"></div>
        <h2 style="font-size: 16px; font-weight: 800; color: #F1FFEF; margin-bottom: 6px;">CONNECTING TO LOCAL ARENA</h2>
        <p style="font-size: 12px; color: #8C8C9A; margin-bottom: 16px;">Establishing low-latency WebSocket connection to host...</p>
        <div style="font-family: monospace; font-size: 11px; color: #00FF88; background: #090F16; padding: 8px; border-radius: 6px; display: inline-block;">
          ws://<span id="conn-host">...</span>/ws
        </div>
      </div>
    </div>

    <!-- VIEW 2: WAITING ROOM -->
    <div id="view-waiting" class="view">
      <div class="card">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px;">
          <h2 style="font-size: 14px; font-weight: 800; color: #00FF88;">WAITING ROOM</h2>
          <span class="badge">LOCAL ARENA</span>
        </div>
        <p style="font-size: 11px; color: #8C8C9A;">Connected to the active local match host via WebSocket.</p>

        <div style="margin-top: 14px; font-size: 11px; font-weight: 700; color: #C0C8D2; text-transform: uppercase;">
          Connected Players & Spectators
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
          <div class="player-avatar">♚</div>
          <div>
            <div class="player-name" id="opponent-name">Host</div>
            <div class="player-meta" id="opponent-meta">Opponent • Connected</div>
          </div>
        </div>
        <div class="clock-box" id="opponent-clock">05:00.0</div>
      </div>

      <!-- History Preview Banner -->
      <div id="history-preview-banner">
        <div style="display:flex; align-items:center; gap:6px;">
          <span style="font-size:12px;">⏳</span>
          <span id="history-preview-text" style="font-size:11px; font-weight:700; color:#38BDF8;">Viewing Historical Move — Board Locked</span>
        </div>
        <button onclick="returnToLive()" style="background:#00FF88; color:#0E141C; border:none; border-radius:6px; font-size:11px; font-weight:700; padding:4px 10px; cursor:pointer;">Return to Live</button>
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
          <div class="player-avatar" style="border: 1px solid #00FF88;">♚</div>
          <div>
            <div class="player-name" id="player-name">Web_Guest</div>
            <div class="player-meta" id="player-meta">Player 2 • Connected</div>
          </div>
        </div>
        <div class="clock-box active" id="player-clock">05:00.0</div>
      </div>

      <!-- Move History Navigation & Ticker Row -->
      <div class="nav-row">
        <div class="nav-btn-group">
          <button class="nav-btn" onclick="navFirst()" title="First Move">|&lt;</button>
          <button class="nav-btn" onclick="navPrev()" title="Previous Move">&lt;</button>
          <button class="nav-btn" onclick="navNext()" title="Next Move">&gt;</button>
          <button class="nav-btn" onclick="navLive()" title="Live Position">&gt;|</button>
        </div>
        <div class="ticker-bar" id="ticker-bar" style="flex: 1;">
          <!-- Interactive move chips -->
        </div>
      </div>

      <!-- Action Row -->
      <div class="btn-row">
        <button class="btn" onclick="flipBoard()">⇄ Flip</button>
        <button class="btn" onclick="requestTakeback()" style="color: #00FF88;">↺ Takeback</button>
        <button class="btn" onclick="offerDraw()">🤝 Draw</button>
        <button class="btn" style="color: #FF6B81;" onclick="resignGame()">⚐ Resign</button>
      </div>

    </div>

  </div>

  <script>
    // ─── Game State ────────────────────────────────────────────────────────────
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
    let selectedSquare = null;
    let legalTargets = [];
    let premove = null; // { from, to }
    let isGameOver = false;
    let clockTimer = null;
    let moveList = [];

    // Move History Navigation state
    let historySnapshots = [{ fen: currentFen, from: null, to: null, san: 'Start' }];
    let viewingPly = null; // null = live, number = historical index

    // Themes
    let activeBoardTheme = 'green';
    let activePieceTheme = 'cburnett';

    const GLYPHS = {
      'P': '♙', 'N': '♘', 'B': '♗', 'R': '♖', 'Q': '♕', 'K': '♔',
      'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚'
    };

    function showView(viewId) {
      document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
      const target = document.getElementById(viewId);
      if (target) target.classList.add('active');
    }

    // ─── Sound System with Dynamic Priority Resolver ───────────────────────────
    function resolveSoundPath(event) {
      let folder = 'default';
      if (activePieceTheme.toLowerCase() === 'anarcandy') {
        folder = 'anarcandy';
      } else {
        const boardLower = activeBoardTheme.toLowerCase().replace('_', '-');
        const knownFolders = ['wood', 'green', 'blue-marble', 'canvas2', 'beat', 'lolz', 'metal', 'newspaper', 'silly', 'standard', 'futuristic', 'piano', 'robot', 'sfx'];
        if (knownFolders.includes(boardLower)) {
          folder = boardLower;
        }
      }

      let file = 'move-self.mp3';
      if (folder === 'anarcandy') {
        if (event === 'move') file = 'brick-move.mp3';
        else if (event === 'capture') file = 'brick-take.mp3';
        else if (event === 'check') file = 'hit.mp3';
        else if (event === 'castle') file = 'brick-castle.mp3';
        else if (event === 'premove') file = 'brick-move.mp3';
        else if (event === 'game-end') file = 'checkmate.mp3';
      } else if (['wood', 'standard', 'futuristic', 'piano', 'robot', 'sfx'].includes(folder)) {
        if (event === 'move') file = 'Move.mp3';
        else if (event === 'capture') file = 'Capture.mp3';
        else if (event === 'check') file = 'Check.mp3';
        else if (event === 'castle') file = 'Move.mp3';
        else if (event === 'premove') file = 'Move.mp3';
        else if (event === 'game-end') file = 'Checkmate.mp3';
      } else {
        if (event === 'move') file = 'move-self.mp3';
        else if (event === 'capture') file = 'capture.mp3';
        else if (event === 'check') file = 'move-check.mp3';
        else if (event === 'castle') file = 'castle.mp3';
        else if (event === 'premove') file = 'premove.mp3';
        else if (event === 'game-end') file = 'game-end.mp3';
      }
      return '/assets/sound/' + folder + '/' + file;
    }

    function playThemedSound(event) {
      try {
        const path = resolveSoundPath(event);
        const audio = new Audio(path);
        audio.volume = 0.85;
        const p = audio.play();
        if (p && p.catch) {
          p.catch(() => playOscillatorFallback(event));
        }
      } catch (_) {
        playOscillatorFallback(event);
      }
    }

    function playOscillatorFallback(event) {
      try {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtx) return;
        const ctx = new AudioCtx();
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.type = 'sine';
        const freq = event === 'capture' ? 320 : (event === 'check' ? 620 : 440);
        osc.frequency.setValueAtTime(freq, ctx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(180, ctx.currentTime + 0.08);
        gain.gain.setValueAtTime(0.25, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.08);
        osc.start();
        osc.stop(ctx.currentTime + 0.08);
      } catch(e) {}
    }

    // ─── WebSocket Connection ──────────────────────────────────────────────────
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
        setTimeout(connectWs, 2500);
      }
    }

    // ─── Packet Dispatcher ─────────────────────────────────────────────────────
    function handlePacket(msg) {
      const type = (msg.type || '').toLowerCase();

      // Silent Keepalive
      if (type === 'ping') {
        if (ws && ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'pong' }));
        }
        return;
      }
      if (type === 'pong') return;

      // Waiting Room Roster
      if (type === 'room_state' || type === 'roomstate') {
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

      // Match Start
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
        historySnapshots = [{ fen: currentFen, from: null, to: null, san: 'Start' }];
        viewingPly = null;
        isGameOver = false;
        selectedSquare = null;
        legalTargets = [];
        premove = null;

        if (msg.boardTheme) activeBoardTheme = msg.boardTheme;
        if (msg.pieceTheme) activePieceTheme = msg.pieceTheme;

        document.getElementById('opponent-name').innerText =
          myColor === 'white' ? (msg.blackName || 'Player 2') : (msg.whiteName || hostName);
        document.getElementById('player-name').innerText =
          myColor === 'white' ? (msg.whiteName || hostName) : (msg.blackName || 'Web_Guest');

        showView('view-match');
        startClockTimer();
        renderBoard();
        updateTicker();
        playThemedSound('game-start');
        return;
      }

      // Live Move Arrived
      if (type === 'move') {
        const prevSelected = selectedSquare;
        const queuedPremove = premove;

        currentFen = msg.fen || currentFen;
        lastMoveFrom = msg.from;
        lastMoveTo = msg.to;
        if (msg.whiteTimeMs != null) whiteTimeMs = msg.whiteTimeMs;
        if (msg.blackTimeMs != null) blackTimeMs = msg.blackTimeMs;
        activeTurn = (currentFen.split(' ')[1] === 'w') ? 'white' : 'black';

        // Add to history snapshots
        const sanStr = msg.san || (msg.from && msg.to ? (msg.from + '-' + msg.to) : 'Move');
        moveList.push(sanStr);
        historySnapshots.push({
          fen: currentFen,
          from: msg.from,
          to: msg.to,
          san: sanStr
        });

        // Live move snaps view back to live
        viewingPly = null;

        // Contextual Sound
        const inCheck = isKingInCheck(currentFen, activeTurn);
        if (inCheck) {
          playThemedSound('check');
        } else if (sanStr.includes('x')) {
          playThemedSound('capture');
        } else if (sanStr === 'O-O' || sanStr === 'O-O-O') {
          playThemedSound('castle');
        } else {
          playThemedSound('move');
        }

        // ── Premove & Selection Preservation ──
        if (queuedPremove) {
          premove = null;
          // Validate premove on updated board state
          const legalDestinations = getLegalMoves(currentFen, queuedPremove.from);
          if (legalDestinations.includes(queuedPremove.to)) {
            // Auto-execute legal premove!
            const boardMap = getBoardMap(currentFen);
            const p = boardMap[queuedPremove.from];
            let promo = null;
            if (p && (p.char === 'P' || p.char === 'p')) {
              if (p.color === 'white' && queuedPremove.to.endsWith('8')) promo = 'q';
              if (p.color === 'black' && queuedPremove.to.endsWith('1')) promo = 'q';
            }
            sendMove(queuedPremove.from, queuedPremove.to, promo);
          } else {
            // Silently cancel without illegal move alert or error sound
          }
        } else if (prevSelected) {
          // Check if piece on prevSelected is still friendly on new FEN
          const boardMap = getBoardMap(currentFen);
          const p = boardMap[prevSelected];
          if (p && p.color === myColor) {
            // Keep selected & recalculate legal targets on new board state silently!
            selectedSquare = prevSelected;
            legalTargets = getLegalMoves(currentFen, prevSelected);
          } else {
            selectedSquare = null;
            legalTargets = [];
          }
        }

        renderBoard();
        updateTicker();
        return;
      }

      // Sync State (Spectator / Reconnect)
      if (type === 'sync') {
        currentFen = msg.fen;
        if (msg.moveHistory) moveList = msg.moveHistory;
        if (msg.whiteTimeMs != null) whiteTimeMs = msg.whiteTimeMs;
        if (msg.blackTimeMs != null) blackTimeMs = msg.blackTimeMs;
        activeTurn = (currentFen.split(' ')[1] === 'w') ? 'white' : 'black';

        historySnapshots = [{ fen: currentFen, from: null, to: null, san: 'Live' }];
        viewingPly = null;

        showView('view-match');
        startClockTimer();
        renderBoard();
        updateTicker();
        return;
      }

      // Game Over
      if (type === 'game_over' || type === 'gameover') {
        isGameOver = true;
        clearInterval(clockTimer);
        playThemedSound('game-end');
        alert('Match Ended: ' + (msg.reason || 'Game Concluded') + (msg.winnerId ? ' (Winner: ' + msg.winnerId + ')' : ''));
        return;
      }

      // Takeback Request
      if (type === 'takeback_req' || type === 'takebackreq' || type === 'takeback_request') {
        const accept = confirm('Opponent requested a move takeback. Grant it?');
        if (ws && ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({
            type: 'takeback_res',
            accepted: accept
          }));
        }
        return;
      }

      // Takeback Response
      if (type === 'takeback_res' || type === 'takebackres') {
        if (msg.accepted) {
          if (msg.revertedFen) currentFen = msg.revertedFen;
          activeTurn = (currentFen.split(' ')[1] === 'w') ? 'white' : 'black';
          selectedSquare = null;
          legalTargets = [];
          premove = null;
          viewingPly = null;
          playThemedSound('takeback');
          renderBoard();
          alert('Takeback granted!');
        } else {
          alert('Takeback request declined.');
        }
        return;
      }
    }

    // ─── Chess Rules Engine (JavaScript) ───────────────────────────────────────
    function getBoardMap(fen) {
      const placement = fen.split(' ')[0];
      const rows = placement.split('/');
      const map = {};
      for (let r = 0; r < 8; r++) {
        const rowStr = rows[r];
        let c = 0;
        for (let i = 0; i < rowStr.length; i++) {
          const ch = rowStr[i];
          const empty = parseInt(ch, 10);
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

    function sqToRowCol(sq) {
      const c = sq.charCodeAt(0) - 97;
      const r = 8 - parseInt(sq[1], 10);
      return [r, c];
    }

    function rowColToSq(r, c) {
      return String.fromCharCode(97 + c) + (8 - r);
    }

    function getPseudoLegalMoves(fen, sq) {
      const boardMap = getBoardMap(fen);
      const piece = boardMap[sq];
      if (!piece) return [];
      const color = piece.color;
      const char = piece.char;
      const [r, c] = sqToRowCol(sq);
      const moves = [];

      function addIfValid(nr, nc) {
        if (nr < 0 || nr > 7 || nc < 0 || nc > 7) return false;
        const destSq = rowColToSq(nr, nc);
        const destP = boardMap[destSq];
        if (!destP) {
          moves.push(destSq);
          return true;
        } else if (destP.color !== color) {
          moves.push(destSq);
          return false;
        }
        return false;
      }

      // Pawns
      if (char === 'P' || char === 'p') {
        const dir = color === 'white' ? -1 : 1;
        const startRow = color === 'white' ? 6 : 1;
        const f1r = r + dir;
        if (f1r >= 0 && f1r <= 7) {
          const f1Sq = rowColToSq(f1r, c);
          if (!boardMap[f1Sq]) {
            moves.push(f1Sq);
            if (r === startRow) {
              const f2r = r + dir * 2;
              const f2Sq = rowColToSq(f2r, c);
              if (!boardMap[f2Sq]) moves.push(f2Sq);
            }
          }
        }
        for (const dc of [-1, 1]) {
          const capC = c + dc;
          const capR = r + dir;
          if (capC >= 0 && capC <= 7 && capR >= 0 && capR <= 7) {
            const capSq = rowColToSq(capR, capC);
            const destP = boardMap[capSq];
            if (destP && destP.color !== color) {
              moves.push(capSq);
            }
          }
        }
      }

      // Knights
      else if (char === 'N' || char === 'n') {
        const offsets = [
          [-2, -1], [-2, 1], [-1, -2], [-1, 2],
          [1, -2], [1, 2], [2, -1], [2, 1]
        ];
        for (const [dr, dc] of offsets) addIfValid(r + dr, c + dc);
      }

      // Bishops
      else if (char === 'B' || char === 'b') {
        for (const [dr, dc] of [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
          let s = 1;
          while (addIfValid(r + dr * s, c + dc * s)) s++;
        }
      }

      // Rooks
      else if (char === 'R' || char === 'r') {
        for (const [dr, dc] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          let s = 1;
          while (addIfValid(r + dr * s, c + dc * s)) s++;
        }
      }

      // Queens
      else if (char === 'Q' || char === 'q') {
        for (const [dr, dc] of [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]]) {
          let s = 1;
          while (addIfValid(r + dr * s, c + dc * s)) s++;
        }
      }

      // Kings
      else if (char === 'K' || char === 'k') {
        for (const [dr, dc] of [[-1, -1], [-1, 1], [1, -1], [1, 1], [-1, 0], [1, 0], [0, -1], [0, 1]]) {
          addIfValid(r + dr, c + dc);
        }
        // Castling
        const castling = fen.split(' ')[2] || '';
        if (color === 'white' && r === 7 && c === 4) {
          if (castling.includes('K') && !boardMap['f1'] && !boardMap['g1']) moves.push('g1');
          if (castling.includes('Q') && !boardMap['d1'] && !boardMap['c1'] && !boardMap['b1']) moves.push('c1');
        } else if (color === 'black' && r === 0 && c === 4) {
          if (castling.includes('k') && !boardMap['f8'] && !boardMap['g8']) moves.push('g8');
          if (castling.includes('q') && !boardMap['d8'] && !boardMap['c8'] && !boardMap['b8']) moves.push('c8');
        }
      }

      return moves;
    }

    function isSquareAttacked(boardMap, targetSq, attackerColor) {
      const [tr, tc] = sqToRowCol(targetSq);
      for (let r = 0; r < 8; r++) {
        for (let c = 0; c < 8; c++) {
          const sq = rowColToSq(r, c);
          const p = boardMap[sq];
          if (p && p.color === attackerColor) {
            const char = p.char;
            const dr = tr - r;
            const dc = tc - c;

            if (char === 'P' || char === 'p') {
              const dir = attackerColor === 'white' ? -1 : 1;
              if (dr === dir && Math.abs(dc) === 1) return true;
            } else if (char === 'N' || char === 'n') {
              if ((Math.abs(dr) === 1 && Math.abs(dc) === 2) || (Math.abs(dr) === 2 && Math.abs(dc) === 1)) return true;
            } else if (char === 'K' || char === 'k') {
              if (Math.abs(dr) <= 1 && Math.abs(dc) <= 1) return true;
            } else {
              const isDiag = Math.abs(dr) === Math.abs(dc);
              const isOrth = dr === 0 || dc === 0;
              const isBishop = char === 'B' || char === 'b';
              const isRook = char === 'R' || char === 'r';
              const isQueen = char === 'Q' || char === 'q';

              if ((isDiag && (isBishop || isQueen)) || (isOrth && (isRook || isQueen))) {
                const stepR = dr === 0 ? 0 : (dr > 0 ? 1 : -1);
                const stepC = dc === 0 ? 0 : (dc > 0 ? 1 : -1);
                let curR = r + stepR;
                let curC = c + stepC;
                let blocked = false;
                while (curR !== tr || curC !== tc) {
                  const curSq = rowColToSq(curR, curC);
                  if (boardMap[curSq]) {
                    blocked = true;
                    break;
                  }
                  curR += stepR;
                  curC += stepC;
                }
                if (!blocked) return true;
              }
            }
          }
        }
      }
      return false;
    }

    function findKingSq(boardMap, color) {
      const target = color === 'white' ? 'K' : 'k';
      for (let r = 0; r < 8; r++) {
        for (let c = 0; c < 8; c++) {
          const sq = rowColToSq(r, c);
          if (boardMap[sq] && boardMap[sq].char === target) return sq;
        }
      }
      return null;
    }

    function isKingInCheck(fen, color) {
      const map = getBoardMap(fen);
      const king = findKingSq(map, color);
      if (!king) return false;
      const opp = color === 'white' ? 'black' : 'white';
      return isSquareAttacked(map, king, opp);
    }

    function getLegalMoves(fen, sq) {
      const pseudo = getPseudoLegalMoves(fen, sq);
      const boardMap = getBoardMap(fen);
      const piece = boardMap[sq];
      if (!piece) return [];
      const color = piece.color;
      const opp = color === 'white' ? 'black' : 'white';
      const legal = [];

      for (const dest of pseudo) {
        const clone = {};
        for (const s in boardMap) clone[s] = boardMap[s];
        clone[dest] = clone[sq];
        delete clone[sq];

        const king = findKingSq(clone, color);
        if (king && !isSquareAttacked(clone, king, opp)) {
          legal.push(dest);
        }
      }
      return legal;
    }

    // ─── Board Rendering ───────────────────────────────────────────────────────
    function renderBoard() {
      const boardEl = document.getElementById('board');
      if (!boardEl) return;
      boardEl.innerHTML = '';

      // Determine active FEN: previewing historical ply or live match
      const isHistorical = viewingPly !== null && viewingPly < historySnapshots.length;
      const activeFen = isHistorical ? historySnapshots[viewingPly].fen : currentFen;
      const boardMap = getBoardMap(activeFen);
      const activeCheckSq = isKingInCheck(activeFen, (activeFen.split(' ')[1] === 'w') ? 'white' : 'black')
          ? findKingSq(boardMap, (activeFen.split(' ')[1] === 'w') ? 'white' : 'black')
          : null;

      const hlFrom = isHistorical ? historySnapshots[viewingPly].from : lastMoveFrom;
      const hlTo = isHistorical ? historySnapshots[viewingPly].to : lastMoveTo;

      // Update Preview Banner
      const previewBanner = document.getElementById('history-preview-banner');
      if (previewBanner) {
        if (isHistorical) {
          previewBanner.style.display = 'flex';
          const txt = document.getElementById('history-preview-text');
          if (txt) {
            txt.innerText = 'Preview Mode (Ply ' + viewingPly + ' / ' + (historySnapshots.length - 1) + ') — Board Locked';
          }
        } else {
          previewBanner.style.display = 'none';
        }
      }

      for (let r = 0; r < 8; r++) {
        for (let c = 0; c < 8; c++) {
          const row = isFlipped ? (7 - r) : r;
          const col = isFlipped ? (7 - c) : c;
          const sq = String.fromCharCode(97 + col) + (8 - row);
          const isLight = (row + col) % 2 === 0;

          const sqEl = document.createElement('div');
          sqEl.className = 'sq ' + (isLight ? 'light' : 'dark');
          sqEl.dataset.sq = sq;

          // Last-move highlight (from & to)
          if (sq === hlFrom) sqEl.classList.add('last-from');
          if (sq === hlTo) sqEl.classList.add('last-to');

          // Selection highlight
          if (!isHistorical && sq === selectedSquare) sqEl.classList.add('selected');

          // Premove highlight
          if (!isHistorical && premove && (sq === premove.from || sq === premove.to)) {
            sqEl.classList.add('premove');
          }

          // Check flash highlight
          if (sq === activeCheckSq) sqEl.classList.add('in-check');

          // Piece rendering
          const piece = boardMap[sq];
          if (piece) {
            const pEl = document.createElement('span');
            pEl.className = 'piece ' + (piece.color === 'white' ? 'w' : 'b');
            pEl.innerText = piece.glyph;
            sqEl.appendChild(pEl);
          }

          // Legal Move Indicators (dots & capture rings)
          if (!isHistorical && legalTargets.includes(sq)) {
            if (piece) {
              const cap = document.createElement('div');
              cap.className = 'legal-capture';
              sqEl.appendChild(cap);
            } else {
              const dot = document.createElement('div');
              dot.className = 'legal-dot';
              sqEl.appendChild(dot);
            }
          }

          sqEl.onclick = () => onSquareClicked(sq);
          boardEl.appendChild(sqEl);
        }
      }

      updateClockHighlight();
    }

    // ─── Square Tap Handler ────────────────────────────────────────────────────
    function onSquareClicked(sq) {
      if (isGameOver) return;
      if (myRole !== 'player') return;

      // In history preview mode: board input is locked!
      if (viewingPly !== null) {
        alert('Board input locked in preview mode. Tap "Return to Live" to make moves.');
        return;
      }

      const boardMap = getBoardMap(currentFen);
      const piece = boardMap[sq];
      const isFriendly = piece && piece.color === myColor;

      // ── It is MY turn ──
      if (activeTurn === myColor) {
        if (!selectedSquare) {
          if (isFriendly) {
            selectedSquare = sq;
            legalTargets = getLegalMoves(currentFen, sq);
            renderBoard();
          }
        } else if (selectedSquare === sq) {
          // Deselect
          selectedSquare = null;
          legalTargets = [];
          renderBoard();
        } else if (isFriendly) {
          // Check castling target (e.g. king selected and clicked rook)
          if (legalTargets.includes(sq)) {
            const from = selectedSquare;
            selectedSquare = null;
            legalTargets = [];
            sendMove(from, sq, null);
          } else {
            // Switch selection smoothly to new friendly piece!
            selectedSquare = sq;
            legalTargets = getLegalMoves(currentFen, sq);
            renderBoard();
          }
        } else {
          // Target is empty or enemy piece
          if (legalTargets.includes(sq)) {
            const from = selectedSquare;
            selectedSquare = null;
            legalTargets = [];

            const p = boardMap[from];
            let promo = null;
            if (p && (p.char === 'P' || p.char === 'p')) {
              if (p.color === 'white' && sq.endsWith('8')) promo = 'q';
              if (p.color === 'black' && sq.endsWith('1')) promo = 'q';
            }
            sendMove(from, sq, promo);
          } else {
            // Tapped illegal square -> clear selection
            selectedSquare = null;
            legalTargets = [];
            renderBoard();
          }
        }
      }

      // ── It is OPPONENT'S turn (Premove / Inspect legal paths) ──
      else {
        if (!selectedSquare) {
          if (isFriendly) {
            selectedSquare = sq;
            legalTargets = getLegalMoves(currentFen, sq);
            renderBoard();
          }
        } else if (selectedSquare === sq) {
          // Deselect
          selectedSquare = null;
          legalTargets = [];
          renderBoard();
        } else if (isFriendly) {
          // Switch selection smoothly to another piece!
          selectedSquare = sq;
          legalTargets = getLegalMoves(currentFen, sq);
          renderBoard();
        } else {
          // Queue premove from selectedSquare to sq!
          premove = { from: selectedSquare, to: sq };
          selectedSquare = null;
          legalTargets = [];
          playThemedSound('premove');
          renderBoard();
        }
      }
    }

    function sendMove(from, to, promo) {
      if (!ws || ws.readyState !== WebSocket.OPEN) return;
      const pkt = {
        type: 'move',
        from: from,
        to: to
      };
      if (promo) pkt.promotion = promo;
      ws.send(JSON.stringify(pkt));
    }

    // ─── Move History Navigation Controls ──────────────────────────────────────
    function navFirst() {
      if (historySnapshots.length === 0) return;
      viewingPly = 0;
      renderBoard();
      updateTicker();
    }

    function navPrev() {
      if (historySnapshots.length === 0) return;
      if (viewingPly === null) {
        viewingPly = Math.max(0, historySnapshots.length - 2);
      } else if (viewingPly > 0) {
        viewingPly--;
      }
      renderBoard();
      updateTicker();
    }

    function navNext() {
      if (viewingPly === null) return;
      viewingPly++;
      if (viewingPly >= historySnapshots.length - 1) {
        viewingPly = null;
      }
      renderBoard();
      updateTicker();
    }

    function navLive() {
      viewingPly = null;
      renderBoard();
      updateTicker();
    }

    function returnToLive() {
      viewingPly = null;
      renderBoard();
      updateTicker();
    }

    function navToPly(index) {
      if (index < 0 || index >= historySnapshots.length) return;
      if (index === historySnapshots.length - 1) {
        viewingPly = null;
      } else {
        viewingPly = index;
      }
      renderBoard();
      updateTicker();
    }

    function updateTicker() {
      const ticker = document.getElementById('ticker-bar');
      if (!ticker) return;
      if (moveList.length === 0) {
        ticker.innerText = 'Game started. Awaiting opening move...';
        return;
      }
      ticker.innerHTML = '';
      for (let i = 0; i < moveList.length; i++) {
        const chip = document.createElement('span');
        const isActive = (viewingPly === i + 1) || (viewingPly === null && i === moveList.length - 1);
        chip.className = 'move-chip' + (isActive ? ' active' : '');
        const moveNum = Math.floor(i / 2) + 1;
        const prefix = (i % 2 === 0) ? (moveNum + '. ') : '';
        chip.innerText = prefix + moveList[i];
        chip.onclick = () => navToPly(i + 1);
        ticker.appendChild(chip);
      }
      ticker.scrollLeft = ticker.scrollWidth;
    }

    // ─── Actions & Clocks ──────────────────────────────────────────────────────
    function flipBoard() {
      isFlipped = !isFlipped;
      renderBoard();
    }

    function requestTakeback() {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
          type: 'takeback_req',
          requesterId: myPlayerId
        }));
        alert('Takeback requested... Waiting for opponent response.');
      }
    }

    function offerDraw() {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'draw_offer' }));
        alert('Draw offer sent to opponent.');
      }
    }

    function resignGame() {
      if (!confirm('Are you sure you want to resign the match?')) return;
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
          type: 'game_over',
          reason: 'resignation',
          winnerId: hostName
        }));
      }
    }

    function formatTime(ms) {
      const totalSec = Math.max(0, Math.floor(ms / 1000));
      const m = Math.floor(totalSec / 60);
      const s = totalSec % 60;
      const tenths = Math.floor((ms % 1000) / 100);
      return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s + '.' + tenths;
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

        const myTime = myColor === 'white' ? whiteTimeMs : blackTimeMs;
        const oppTime = myColor === 'white' ? blackTimeMs : whiteTimeMs;

        const pEl = document.getElementById('player-clock');
        const oEl = document.getElementById('opponent-clock');
        if (pEl) pEl.innerText = formatTime(myTime);
        if (oEl) oEl.innerText = formatTime(oppTime);
      }, 100);
    }

    function updateClockHighlight() {
      const pEl = document.getElementById('player-clock');
      const oEl = document.getElementById('opponent-clock');
      if (!pEl || !oEl) return;

      const isMyTurn = activeTurn === myColor;
      pEl.className = 'clock-box' + (isMyTurn ? ' active' : '');
      oEl.className = 'clock-box' + (!isMyTurn ? ' active' : '');
    }

    // Auto connect on page load
    window.onload = () => {
      connectWs();
    };
  </script>
</body>
</html>''';
}
