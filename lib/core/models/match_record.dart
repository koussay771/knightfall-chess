import 'dart:convert';

class MatchRecord {
  final String id;
  final DateTime date;
  final String opponentName;
  final String result; // 'win' | 'loss' | 'draw'
  final String reason; // 'checkmate' | 'timeout' | 'resign' | 'draw' | 'stalemate'
  final String mode; // 'standard' | 'koth' | 'dare'
  final String? dareText;
  final List<String> moves; // SAN move list
  final String pgn;
  final int myMaterialAdvantage;

  const MatchRecord({
    required this.id,
    required this.date,
    required this.opponentName,
    required this.result,
    required this.reason,
    required this.mode,
    this.dareText,
    required this.moves,
    required this.pgn,
    required this.myMaterialAdvantage,
  });

  factory MatchRecord.fromMap(Map<String, dynamic> map) {
    dynamic movesData = map['moves'];
    List<String> parsedMoves = [];
    if (movesData is String) {
      try {
        parsedMoves = List<String>.from(jsonDecode(movesData) as List);
      } catch (_) {
        parsedMoves = movesData.split(',').where((s) => s.isNotEmpty).toList();
      }
    } else if (movesData is List) {
      parsedMoves = List<String>.from(movesData);
    }

    return MatchRecord(
      id: map['id'] as String,
      date: map['date'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
          : DateTime.tryParse(map['date'].toString()) ?? DateTime.now(),
      opponentName: map['opponentName'] as String,
      result: map['result'] as String,
      reason: map['reason'] as String,
      mode: map['mode'] as String,
      dareText: map['dareText'] as String?,
      moves: parsedMoves,
      pgn: map['pgn'] as String? ?? '',
      myMaterialAdvantage: map['myMaterialAdvantage'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'opponentName': opponentName,
      'result': result,
      'reason': reason,
      'mode': mode,
      'dareText': dareText,
      'moves': jsonEncode(moves),
      'pgn': pgn,
      'myMaterialAdvantage': myMaterialAdvantage,
    };
  }

  factory MatchRecord.fromJson(Map<String, dynamic> json) =>
      MatchRecord.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  MatchRecord copyWith({
    String? id,
    DateTime? date,
    String? opponentName,
    String? result,
    String? reason,
    String? mode,
    String? dareText,
    List<String>? moves,
    String? pgn,
    int? myMaterialAdvantage,
  }) {
    return MatchRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      opponentName: opponentName ?? this.opponentName,
      result: result ?? this.result,
      reason: reason ?? this.reason,
      mode: mode ?? this.mode,
      dareText: dareText ?? this.dareText,
      moves: moves ?? this.moves,
      pgn: pgn ?? this.pgn,
      myMaterialAdvantage: myMaterialAdvantage ?? this.myMaterialAdvantage,
    );
  }

  @override
  String toString() =>
      'MatchRecord(id: $id, date: $date, opponent: $opponentName, result: $result, reason: $reason, mode: $mode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
