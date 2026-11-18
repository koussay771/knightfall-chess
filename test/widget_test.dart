import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_hotspot/main.dart';

void main() {
  testWidgets('ChessHotspotApp root widget builds LobbyScreen cleanly',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: ChessHotspotApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The Play tab should be visible with Host Game and Join Game buttons
    expect(find.text('Host Game'), findsOneWidget);
    expect(find.text('Join Game'), findsOneWidget);
    // Bottom nav should show Chess Hotspot label
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
  });
}
