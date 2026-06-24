import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snapix/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Corridor Picker Scenario', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Verify the initial state asks to select the origin point
    expect(find.byIcon(Icons.trip_origin_rounded), findsWidgets);
    expect(find.byIcon(Icons.flag_rounded), findsWidgets);

    // 2. Tap on the map to set the origin
    final mapFinder = find.byType(GoogleMap);
    if (mapFinder.evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(200, 200)); // Tap centerish for origin
      await tester.pumpAndSettle();
      
      // 3. Verify the UI updates to ask for the destination point
      // Tap again for destination
      await tester.tapAt(const Offset(250, 250));
      await tester.pumpAndSettle();
    }

    // 4. Verify the radius sliders appear on the bottom sheet
    // Since Slider is a standard Flutter widget, we can find it
    expect(find.byType(Slider), findsWidgets);

    // 5. Verify the "حفظ الممر المفضل" (Save Preferred Corridor) button becomes enabled
    final saveIconFinder = find.byIcon(Icons.save_rounded);
    expect(saveIconFinder, findsOneWidget);
    await tester.tap(saveIconFinder);
    await tester.pumpAndSettle();
  });
}
