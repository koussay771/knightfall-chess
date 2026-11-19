import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/lobby/lobby_screen.dart';
import 'core/constants/theme_constants.dart';
import 'core/providers/user_profile_provider.dart';

void main() {
  runApp(const ProviderScope(child: ChessHotspotApp()));
}

class ChessHotspotApp extends ConsumerWidget {
  const ChessHotspotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final theme = AppThemes.buildDarkTheme(profile.accentColor);

    return MaterialApp(
      title: 'Chess Hotspot',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: const LobbyScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
