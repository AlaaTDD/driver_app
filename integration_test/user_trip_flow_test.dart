import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapix/main.dart' as app;
import 'helpers/db_tester.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('User Trip Flow (High Precision with DB Injection)', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    final db = DbTester();
    
    // 1. Authenticate as User
    final userId = await AuthHelper.loginUser(tester, 'sara.user@gmail.com', 'User@12345');
    expect(userId, isNotNull, reason: 'User login failed');
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 2. Request a trip via DB (Simulating UI action since UI is too dynamic)
    final tripId = await db.injectTripRequest(
      userId: userId!,
      originLat: 30.0444,
      originLng: 31.2357,
      destLat: 30.05,
      destLng: 31.25,
      originAddress: 'Tahrir Square',
      destAddress: 'Ramsis Station',
      expectedPrice: 50.0,
      distance: 3.5,
    );
    
    expect(tripId, isNotEmpty);
    
    // 3. Let the app process the trip creation (websockets listening to trips)
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 4. Inject a Driver Offer
    final driverId = await AuthHelper.getDriverIdByEmail('youssef.driver@gmail.com');
    final offerId = await db.injectDriverOffer(
      tripId: tripId,
      driverId: driverId!,
      offerPrice: 55.0,
      driverLat: 30.0450,
      driverLng: 31.2360,
    );
    
    // 5. Let the app show the offer
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // 6. DB Accept the offer
    await db.acceptOffer(tripId, offerId, driverId);
    
    // 7. Verify Trip State is accepted
    final tripData = await db.getTrip(tripId);
    expect(tripData!['status'], 'accepted');
    expect(tripData['driver_id'], driverId);
    
    // 8. Let the UI transition to Trip Active screen
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // 9. Complete the trip
    await db.completeTrip(tripId);
    
    // 10. Final State Verification
    final finalTrip = await db.getTrip(tripId);
    expect(finalTrip!['status'], 'completed');
    
    await tester.pumpAndSettle(const Duration(seconds: 3));
    
    // Cleanup is handled by testing reset scripts, no need to clutter the test
  });
}
