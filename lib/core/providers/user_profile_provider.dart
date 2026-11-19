import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme_constants.dart';

/// Central immutable profile model for reactive state sharing across screens.
class UserProfile {
  final String name;
  final String avatar;
  final Color accentColor;
  final int elo;
  final int winRate;

  const UserProfile({
    this.name = 'Player',
    this.avatar = '♟️',
    this.accentColor = AppColors.neonGreen,
    this.elo = 1845,
    this.winRate = 68,
  });

  UserProfile copyWith({
    String? name,
    String? avatar,
    Color? accentColor,
    int? elo,
    int? winRate,
  }) {
    return UserProfile(
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      accentColor: accentColor ?? this.accentColor,
      elo: elo ?? this.elo,
      winRate: winRate ?? this.winRate,
    );
  }
}

/// Reactive StateNotifier that persists changes to [SharedPreferences]
/// and immediately notifies all listening widgets (Lobby, Network, Board, Profile).
class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(const UserProfile()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('player_name') ?? 'Player';
      final avatar = prefs.getString('player_avatar') ?? '♟️';
      final colorVal = prefs.getInt('player_color');
      final accentColor =
          colorVal != null ? Color(colorVal) : AppColors.neonGreen;

      state = UserProfile(
        name: name,
        avatar: avatar,
        accentColor: accentColor,
      );
    } catch (_) {}
  }

  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(name: trimmed);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_name', trimmed);
    } catch (_) {}
  }

  Future<void> updateAvatar(String avatar) async {
    state = state.copyWith(avatar: avatar);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_avatar', avatar);
    } catch (_) {}
  }

  Future<void> updateAccentColor(Color color) async {
    state = state.copyWith(accentColor: color);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('player_color', color.toARGB32());
    } catch (_) {}
  }

  Future<void> updateProfile({
    String? name,
    String? avatar,
    Color? accentColor,
  }) async {
    final newName = name?.trim().isNotEmpty == true ? name!.trim() : state.name;
    final newAvatar = avatar ?? state.avatar;
    final newColor = accentColor ?? state.accentColor;

    state = state.copyWith(
      name: newName,
      avatar: newAvatar,
      accentColor: newColor,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      if (name != null && name.trim().isNotEmpty) {
        await prefs.setString('player_name', newName);
      }
      if (avatar != null) {
        await prefs.setString('player_avatar', newAvatar);
      }
      if (accentColor != null) {
        await prefs.setInt('player_color', newColor.toARGB32());
      }
    } catch (_) {}
  }
}

/// Global reactive provider for the active user profile.
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});
