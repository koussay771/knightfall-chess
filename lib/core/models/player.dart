// Player model — exchanged in HANDSHAKE packet

class Player {
  final String id; // UUID
  final String name;
  final String role; // 'player' | 'spectator'
  final String? avatarIcon; // emoji or icon name
  final int avatarColor; // color int (ARGB)

  const Player({
    required this.id,
    required this.name,
    required this.role,
    this.avatarIcon,
    this.avatarColor = 0xFF769656,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      avatarIcon: json['avatarIcon'] as String?,
      avatarColor: json['avatarColor'] as int? ?? 0xFF769656,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      if (avatarIcon != null) 'avatarIcon': avatarIcon,
      'avatarColor': avatarColor,
    };
  }

  Player copyWith({
    String? id,
    String? name,
    String? role,
    String? avatarIcon,
    int? avatarColor,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }

  @override
  String toString() =>
      'Player(id: $id, name: $name, role: $role, avatarIcon: $avatarIcon, avatarColor: $avatarColor)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          role == other.role &&
          avatarIcon == other.avatarIcon &&
          avatarColor == other.avatarColor;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      role.hashCode ^
      avatarIcon.hashCode ^
      avatarColor.hashCode;
}
