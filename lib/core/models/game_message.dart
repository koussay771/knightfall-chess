import 'dart:convert';

/// Enum of all message types in the Chess Hotspot protocol.
enum GameMessageType {
  handshake,
  start,
  move,
  takebackReq,
  takebackRes,
  gameOver,
  sync,
  ping,
  pong,
}

extension GameMessageTypeExtension on GameMessageType {
  String get value {
    switch (this) {
      case GameMessageType.handshake:
        return 'handshake';
      case GameMessageType.start:
        return 'start';
      case GameMessageType.move:
        return 'move';
      case GameMessageType.takebackReq:
        return 'takeback_req';
      case GameMessageType.takebackRes:
        return 'takeback_res';
      case GameMessageType.gameOver:
        return 'game_over';
      case GameMessageType.sync:
        return 'sync';
      case GameMessageType.ping:
        return 'ping';
      case GameMessageType.pong:
        return 'pong';
    }
  }

  static GameMessageType fromString(String s) {
    final lower = s.toLowerCase().replaceAll('-', '_');
    switch (lower) {
      case 'handshake':
        return GameMessageType.handshake;
      case 'start':
      case 'game_start':
        return GameMessageType.start;
      case 'move':
        return GameMessageType.move;
      case 'takeback_req':
      case 'takebackreq':
        return GameMessageType.takebackReq;
      case 'takeback_res':
      case 'takebackres':
        return GameMessageType.takebackRes;
      case 'game_over':
      case 'gameover':
        return GameMessageType.gameOver;
      case 'sync':
      case 'sync_state':
        return GameMessageType.sync;
      case 'ping':
        return GameMessageType.ping;
      case 'pong':
        return GameMessageType.pong;
      default:
        throw ArgumentError('Unknown message type: $s');
    }
  }
}

/// Base class for all game protocol messages.
abstract class GameMessage {
  final GameMessageType type;

  const GameMessage({required this.type});

  Map<String, dynamic> toJson();

  /// Parse a raw JSON string and return the correct subclass.
  static GameMessage parse(String raw) {
    final Map<String, dynamic> map =
        jsonDecode(raw.trim()) as Map<String, dynamic>;
    final type =
        GameMessageTypeExtension.fromString(map['type'] as String);
    switch (type) {
      case GameMessageType.handshake:
        return HandshakeMessage.fromJson(map);
      case GameMessageType.start:
        return StartMessage.fromJson(map);
      case GameMessageType.move:
        return MoveMessage.fromJson(map);
      case GameMessageType.takebackReq:
        return TakebackReqMessage.fromJson(map);
      case GameMessageType.takebackRes:
        return TakebackResMessage.fromJson(map);
      case GameMessageType.gameOver:
        return GameOverMessage.fromJson(map);
      case GameMessageType.sync:
        return SyncMessage.fromJson(map);
      case GameMessageType.ping:
        return PingMessage.fromJson(map);
      case GameMessageType.pong:
        return PongMessage.fromJson(map);
    }
  }
}

// ---------------------------------------------------------------------------
// Handshake
// ---------------------------------------------------------------------------

class HandshakeMessage extends GameMessage {
  final String playerId;
  final String name;
  final String role; // 'player' | 'spectator'
  final String? avatarIcon;
  final int avatarColor;

  const HandshakeMessage({
    required this.playerId,
    required this.name,
    required this.role,
    this.avatarIcon,
    this.avatarColor = 0xFF769656,
  }) : super(type: GameMessageType.handshake);

  factory HandshakeMessage.fromJson(Map<String, dynamic> json) {
    return HandshakeMessage(
      playerId: json['playerId'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      avatarIcon: json['avatarIcon'] as String?,
      avatarColor: json['avatarColor'] as int? ?? 0xFF769656,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'playerId': playerId,
        'name': name,
        'role': role,
        if (avatarIcon != null) 'avatarIcon': avatarIcon,
        'avatarColor': avatarColor,
      };
}

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

class StartMessage extends GameMessage {
  final String whiteId;
  final String blackId;
  final int timeControl; // seconds (0 = unlimited)
  final int increment; // seconds
  final String mode; // 'standard' | 'koth' | 'dare'
  final String? dareText;

  const StartMessage({
    required this.whiteId,
    required this.blackId,
    required this.timeControl,
    required this.increment,
    required this.mode,
    this.dareText,
  }) : super(type: GameMessageType.start);

  factory StartMessage.fromJson(Map<String, dynamic> json) {
    return StartMessage(
      whiteId: json['whiteId'] as String,
      blackId: json['blackId'] as String,
      timeControl: json['timeControl'] as int,
      increment: json['increment'] as int,
      mode: json['mode'] as String,
      dareText: json['dareText'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'whiteId': whiteId,
        'blackId': blackId,
        'timeControl': timeControl,
        'increment': increment,
        'mode': mode,
        if (dareText != null) 'dareText': dareText,
      };
}

// ---------------------------------------------------------------------------
// Move
// ---------------------------------------------------------------------------

class MoveMessage extends GameMessage {
  final String from; // algebraic e.g. "e2"
  final String to; // algebraic e.g. "e4"
  final String? promotion; // piece letter e.g. "q"
  final String fen; // position after the move
  final int whiteTimeMs;
  final int blackTimeMs;

  const MoveMessage({
    required this.from,
    required this.to,
    this.promotion,
    required this.fen,
    required this.whiteTimeMs,
    required this.blackTimeMs,
  }) : super(type: GameMessageType.move);

  factory MoveMessage.fromJson(Map<String, dynamic> json) {
    return MoveMessage(
      from: json['from'] as String,
      to: json['to'] as String,
      promotion: json['promotion'] as String?,
      fen: json['fen'] as String,
      whiteTimeMs: json['whiteTimeMs'] as int,
      blackTimeMs: json['blackTimeMs'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
        'fen': fen,
        'whiteTimeMs': whiteTimeMs,
        'blackTimeMs': blackTimeMs,
      };
}

// ---------------------------------------------------------------------------
// Takeback Request
// ---------------------------------------------------------------------------

class TakebackReqMessage extends GameMessage {
  final String requesterId;

  const TakebackReqMessage({required this.requesterId})
      : super(type: GameMessageType.takebackReq);

  factory TakebackReqMessage.fromJson(Map<String, dynamic> json) {
    return TakebackReqMessage(requesterId: json['requesterId'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'requesterId': requesterId,
      };
}

// ---------------------------------------------------------------------------
// Takeback Response
// ---------------------------------------------------------------------------

class TakebackResMessage extends GameMessage {
  final bool accepted;
  final String? revertedFen; // FEN after the takeback, if accepted

  const TakebackResMessage({required this.accepted, this.revertedFen})
      : super(type: GameMessageType.takebackRes);

  factory TakebackResMessage.fromJson(Map<String, dynamic> json) {
    return TakebackResMessage(
      accepted: json['accepted'] as bool,
      revertedFen: json['revertedFen'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'accepted': accepted,
        if (revertedFen != null) 'revertedFen': revertedFen,
      };
}

// ---------------------------------------------------------------------------
// Game Over
// ---------------------------------------------------------------------------

class GameOverMessage extends GameMessage {
  final String reason; // 'checkmate' | 'timeout' | 'resign' | 'draw' | 'stalemate'
  final String? winnerId; // null for draws

  const GameOverMessage({required this.reason, this.winnerId})
      : super(type: GameMessageType.gameOver);

  factory GameOverMessage.fromJson(Map<String, dynamic> json) {
    return GameOverMessage(
      reason: json['reason'] as String,
      winnerId: json['winnerId'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'reason': reason,
        if (winnerId != null) 'winnerId': winnerId,
      };
}

// ---------------------------------------------------------------------------
// Sync State
// ---------------------------------------------------------------------------

class SyncMessage extends GameMessage {
  final String fen;
  final List<String> moveHistory; // SAN move list
  final int whiteTimeMs;
  final int blackTimeMs;

  const SyncMessage({
    required this.fen,
    required this.moveHistory,
    required this.whiteTimeMs,
    required this.blackTimeMs,
  }) : super(type: GameMessageType.sync);

  factory SyncMessage.fromJson(Map<String, dynamic> json) {
    return SyncMessage(
      fen: json['fen'] as String,
      moveHistory: List<String>.from(json['moveHistory'] as List),
      whiteTimeMs: json['whiteTimeMs'] as int,
      blackTimeMs: json['blackTimeMs'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type.value,
        'fen': fen,
        'moveHistory': moveHistory,
        'whiteTimeMs': whiteTimeMs,
        'blackTimeMs': blackTimeMs,
      };
}

// ---------------------------------------------------------------------------
// Ping / Pong
// ---------------------------------------------------------------------------

class PingMessage extends GameMessage {
  const PingMessage() : super(type: GameMessageType.ping);

  factory PingMessage.fromJson(Map<String, dynamic> _) => const PingMessage();

  @override
  Map<String, dynamic> toJson() => {'type': type.value};
}

class PongMessage extends GameMessage {
  const PongMessage() : super(type: GameMessageType.pong);

  factory PongMessage.fromJson(Map<String, dynamic> _) => const PongMessage();

  @override
  Map<String, dynamic> toJson() => {'type': type.value};
}
