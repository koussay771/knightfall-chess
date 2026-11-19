import 'dart:convert';

/// Pure serialization / deserialization layer for the Chess Hotspot protocol.
/// All TCP packets are newline-delimited JSON strings (\n).
class SyncProtocol {
  SyncProtocol._();

  // ─── Low-level codec ───────────────────────────────────────────────────────

  /// Encodes a [data] map to a newline-terminated JSON string.
  static String encode(Map<String, dynamic> data) => '${jsonEncode(data)}\n';

  /// Decodes a raw (possibly newline-terminated) string to a map.
  static Map<String, dynamic> decode(String raw) =>
      jsonDecode(raw.trim()) as Map<String, dynamic>;

  // ─── Message type constants (Section 3 Protocol) ──────────────────────────

  static const String typeHandshake = 'handshake';
  static const String typeGameStart = 'start';
  static const String typeMove = 'move';
  static const String typeTakebackReq = 'takeback_req';
  static const String typeTakebackRes = 'takeback_res';
  static const String typeGameOver = 'game_over';
  static const String typeSyncState = 'sync';
  static const String typePing = 'ping';
  static const String typePong = 'pong';
  static const String typeRoomState = 'room_state';

  /// Helper to normalize message types (supports snake_case, camelCase, uppercase).
  static String normalizeType(String? rawType) {
    if (rawType == null) return '';
    final lower = rawType.toLowerCase().replaceAll('-', '_');
    switch (lower) {
      case 'handshake':
        return typeHandshake;
      case 'start':
      case 'game_start':
      case 'gamestart':
        return typeGameStart;
      case 'move':
        return typeMove;
      case 'takeback_req':
      case 'takebackreq':
        return typeTakebackReq;
      case 'takeback_res':
      case 'takebackres':
        return typeTakebackRes;
      case 'game_over':
      case 'gameover':
        return typeGameOver;
      case 'sync':
      case 'sync_state':
      case 'syncstate':
        return typeSyncState;
      case 'ping':
        return typePing;
      case 'pong':
        return typePong;
      case 'room_state':
      case 'roomstate':
        return typeRoomState;
      default:
        return lower;
    }
  }

  // ─── Message builders ──────────────────────────────────────────────────────

  /// Broadcast by the host in waiting room when players join or settings update.
  static String roomState({
    required String status,
    required String hostName,
    required String gameMode,
    required int timeControl,
    required List<Map<String, dynamic>> players,
  }) =>
      encode({
        'type': typeRoomState,
        'status': status,
        'hostName': hostName,
        'gameMode': gameMode,
        'timeControl': timeControl,
        'players': players,
      });

  /// Sent immediately after TCP connection is established.
  /// role is 'player' or 'spectator'.
  static String handshake({
    required String playerId,
    required String name,
    required String role,
    String? avatarIcon,
    int? avatarColor,
  }) =>
      encode({
        'type': typeHandshake,
        'playerId': playerId,
        'name': name,
        'role': role,
        if (avatarIcon != null) 'avatarIcon': avatarIcon,
        if (avatarColor != null) 'avatarColor': avatarColor,
      });

  /// Broadcast by the host once both players are ready/connected.
  /// [timeControl] is in seconds (0 = unlimited), [increment] is in seconds.
  /// [mode] is 'standard' | 'koth' | 'dare'.
  static String gameStart({
    required String whiteId,
    required String blackId,
    required int timeControl,
    required int increment,
    required String mode,
    String? dareText,
    String? whiteName,
    String? blackName,
    String? fen,
  }) =>
      encode({
        'type': typeGameStart,
        'whiteId': whiteId,
        'blackId': blackId,
        'timeControl': timeControl,
        'increment': increment,
        'mode': mode,
        if (whiteName != null) 'whiteName': whiteName,
        if (blackName != null) 'blackName': blackName,
        if (fen != null) 'fen': fen,
        if (dareText != null) 'dareText': dareText,
      });

  /// Sent by the moving player after each legal move.
  /// [fen] is the resulting position, times are in milliseconds.
  static String move({
    required String from,
    required String to,
    String? promotion,
    required String fen,
    required int whiteTimeMs,
    required int blackTimeMs,
  }) =>
      encode({
        'type': typeMove,
        'from': from,
        'to': to,
        'promotion': promotion,
        'fen': fen,
        'whiteTimeMs': whiteTimeMs,
        'blackTimeMs': blackTimeMs,
      });

  /// Sent by a player requesting to take back the last move.
  static String takebackReq({required String requesterId}) => encode({
        'type': typeTakebackReq,
        'requesterId': requesterId,
      });

  /// Response to a takeback request.
  /// If [accepted], [revertedFen] contains the FEN after reversal.
  static String takebackRes({
    required bool accepted,
    String? revertedFen,
  }) =>
      encode({
        'type': typeTakebackRes,
        'accepted': accepted,
        if (revertedFen != null) 'revertedFen': revertedFen,
      });

  /// Broadcast when the game concludes.
  /// [reason]: 'checkmate' | 'timeout' | 'resign' | 'draw'
  static String gameOver({
    required String reason,
    String? winnerId,
  }) =>
      encode({
        'type': typeGameOver,
        'reason': reason,
        'winnerId': winnerId,
      });

  /// Full state packet used on Auto-Reconnect & Spectator join.
  static String syncState({
    required String fen,
    required List<String> moveHistory,
    required int whiteTimeMs,
    required int blackTimeMs,
  }) =>
      encode({
        'type': typeSyncState,
        'fen': fen,
        'moveHistory': moveHistory,
        'whiteTimeMs': whiteTimeMs,
        'blackTimeMs': blackTimeMs,
      });

  /// Keepalive heartbeat: Client sends PING every 2 seconds.
  static String ping() => encode({'type': typePing});

  /// Heartbeat response.
  static String pong() => encode({'type': typePong});
}
