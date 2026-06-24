import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapix/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Chatbot Support Scenario', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // NOTE: This assumes the user navigates to the ChatbotScreen first, 
    // or we pump ChatbotScreen directly. If routing is needed, add the push navigation here.

    // 1. Wait for the initial "How can I help you?" welcome message to render
    expect(find.byIcon(Icons.support_agent), findsOneWidget);

    // 2. Find the TextField at the bottom and enter a test message
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);
    await tester.enterText(textFieldFinder, 'مرحباً');
    await tester.pumpAndSettle();

    // 3. Tap the send button (Icons.send_rounded)
    final sendButtonFinder = find.byIcon(Icons.send_rounded);
    expect(sendButtonFinder, findsOneWidget);
    await tester.tap(sendButtonFinder);
    await tester.pumpAndSettle();

    // 4. Wait for the ListView to update and verify the user's message is visible
    expect(find.text('مرحباً'), findsOneWidget);
  });
}
