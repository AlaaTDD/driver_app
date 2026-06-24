import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapix/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pricing and Vehicle Selection Scenario', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Wait for the vehicle types to load and render
    // Assume at least one vehicle chip is visible
    // We can search for the "Car" icon which is directions_car_rounded
    final vehicleIconFinder = find.byIcon(Icons.directions_car_rounded);
    if (vehicleIconFinder.evaluate().isNotEmpty) {
      await tester.tap(vehicleIconFinder.first);
      await tester.pumpAndSettle();
    }

    // 2. Select Payment Method (Cash)
    final cashIconFinder = find.byIcon(Icons.payments_rounded);
    expect(cashIconFinder, findsOneWidget);
    await tester.tap(cashIconFinder);
    await tester.pumpAndSettle();

    // 3. Expand Coupon Input
    final couponIconFinder = find.byIcon(Icons.local_offer_rounded);
    expect(couponIconFinder, findsWidgets);
    await tester.tap(couponIconFinder.first);
    await tester.pumpAndSettle();

    // 4. Type Promo Code
    final couponInputFinder = find.byType(TextField);
    if (couponInputFinder.evaluate().isNotEmpty) {
      await tester.enterText(couponInputFinder, 'TEST10');
      await tester.pumpAndSettle();
    }

    // 5. Verify the bottom "تحديد نقطة الالتقاء" (Select Meeting Point) button is present
    final placeIconFinder = find.byIcon(Icons.place_rounded);
    expect(placeIconFinder, findsWidgets);
  });
}
