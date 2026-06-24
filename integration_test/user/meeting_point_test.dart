import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapix/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Meeting Point Trip Scenario', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Verify the bottom sheet renders
    expect(find.byIcon(Icons.place_rounded), findsWidgets);

    // 2. Verify the "البحث عن سائق" (Search for Driver) button is visible
    final searchIconFinder = find.byIcon(Icons.search_rounded);
    expect(searchIconFinder, findsOneWidget);

    // 3. Tap the "البحث عن سائق" button
    await tester.tap(searchIconFinder);
    await tester.pump(); // We don't pumpAndSettle here because it triggers an infinite loading state animation or network call
    
    // Test passes if it didn't crash up to this point.
  });
}
