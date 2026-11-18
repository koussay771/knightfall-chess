import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/lobby/lobby_screen.dart';
import 'core/constants/theme_constants.dart';

void main() {
  runApp(const ProviderScope(child: ChessHotspotApp()));
}

class ChessHotspotApp extends StatelessWidget {
  const ChessHotspotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Hotspot',
      theme: AppThemes.darkTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: ThemeMode.dark,
      home: const LobbyScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
