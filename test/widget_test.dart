// Basic smoke test for ShuttleLeagueApp.
//
// The app depends on Firebase/auth state at startup, so this only verifies
// the widget tree can be constructed under a ProviderScope without throwing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuttle_league/app/app.dart';

void main() {
  testWidgets('ShuttleLeagueApp builds without throwing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ShuttleLeagueApp(),
      ),
    );

    expect(find.byType(ShuttleLeagueApp), findsOneWidget);
  });
}
