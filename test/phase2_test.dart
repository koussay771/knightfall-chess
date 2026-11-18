import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_hotspot/core/models/match_record.dart';
import 'package:chess_hotspot/features/history/history_screen.dart';
import 'package:chess_hotspot/features/spectator/spectator_screen.dart';

void main() {
  group('Phase 2: Spectator Mode & Match History Tests', () {
    test('MatchRecord serialization toMap and fromMap works seamlessly', () {
      final now = DateTime.now();
      final record = MatchRecord(
        id: 'match-1',
        date: now,
        opponentName: 'Grandmaster',
        result: 'win',
        reason: 'checkmate',
        mode: 'standard',
        dareText: null,
        moves: ['e4', 'e5', 'Qh5', 'Nc6', 'Bc4', 'Nf6', 'Qxf7#'],
        pgn: '1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6 4. Qxf7#',
        myMaterialAdvantage: 3,
      );

      final map = record.toMap();
      expect(map['id'], 'match-1');
      expect(map['opponentName'], 'Grandmaster');
      expect(map['result'], 'win');

      final revived = MatchRecord.fromMap(map);
      expect(revived.id, 'match-1');
      expect(revived.opponentName, 'Grandmaster');
      expect(revived.moves.length, 7);
      expect(revived.result, 'win');
    });

    testWidgets('SpectatorScreen builds read-only board and flip action',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SpectatorScreen(
              playerWhiteName: 'Magnus',
              playerBlackName: 'Hikaru',
            ),
          ),
        ),
      );

      // Verify Spectator header
      expect(find.text('Spectating: Magnus vs Hikaru'), findsOneWidget);
      expect(find.text('Live Spectator Mode (Read-Only)'), findsOneWidget);

      // Verify Clocks
      expect(find.text('Magnus'), findsOneWidget);
      expect(find.text('Hikaru'), findsOneWidget);

      // Verify Flip action button exists
      final flipButton = find.byIcon(Icons.flip_camera_android);
      expect(flipButton, findsOneWidget);

      // Tap Flip action button
      await tester.tap(flipButton);
      await tester.pump();
      expect(find.text('Spectating: Magnus vs Hikaru'), findsOneWidget);
    });

    testWidgets('HistoryScreen displays empty state when no matches exist',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: HistoryScreen()),
        ),
      );

      // Verify Scoreboard
      expect(find.text('Overall Record'), findsOneWidget);
      expect(find.text('WINS'), findsOneWidget);
      expect(find.text('DRAWS'), findsOneWidget);
      expect(find.text('LOSSES'), findsOneWidget);

      // Search bar
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
