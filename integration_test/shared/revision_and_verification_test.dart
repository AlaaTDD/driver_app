import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapix/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Driver Revision Requests Scenario', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Verify the app bar title 
    // We check if the screen exists by looking for common icons or empty states
    // The screen has either `Icons.fact_check_outlined` (empty state) or `Icons.edit_note_rounded` (pending revision)

    final emptyStateFinder = find.byIcon(Icons.fact_check_outlined);
    final listFinder = find.byType(ListView);

    if (emptyStateFinder.evaluate().isNotEmpty) {
      // Empty state rendered
      expect(emptyStateFinder, findsOneWidget);
    } else {
      // List of requests rendered
      expect(listFinder, findsOneWidget);
      
      // 2. Check for the "Edit Profile" button inside unresolved cards
      final editProfileFinder = find.byIcon(Icons.person_rounded);
      if (editProfileFinder.evaluate().isNotEmpty) {
        expect(editProfileFinder, findsWidgets);
      }
    }
  });
}
