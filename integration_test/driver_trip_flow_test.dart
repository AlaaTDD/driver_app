import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapix/main.dart' as app;
import 'helpers/db_tester.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Driver Trip Flow (High Precision with DB Injection)', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    final db = DbTester();
    
    // 1. Authenticate as Driver
    final driverId = await AuthHelper.loginUser(tester, 'youssef.driver@gmail.com', 'Driver@12345');
    expect(driverId, isNotNull, reason: 'Driver login failed');
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 2. Set driver as online in DB (Simulate toggle)
    await db.setDriverStatus(driverId!, true);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 3. Inject a Trip Request from a User
    final userId = await AuthHelper.getDriverIdByEmail('sara.user@gmail.com');
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
    
    // 4. Let the app process the incoming trip via websocket
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 5. Driver sends an offer via DB (Simulate offer slider)
    final offerId = await db.injectDriverOffer(
      tripId: tripId,
      driverId: driverId,
      offerPrice: 55.0,
      driverLat: 30.0450,
      driverLng: 31.2360,
    );
    expect(offerId, isNotEmpty);

    // 6. DB Accept the offer (Simulate User accepting it)
    await db.acceptOffer(tripId, offerId, driverId);
    
    // 7. Verify Trip State is accepted
    final tripData = await db.getTrip(tripId);
    expect(tripData!['status'], 'accepted');
    expect(tripData['driver_id'], driverId);
    
    // 8. Let the UI transition to Active Ride screen
    await tester.pumpAndSettle(const Duration(seconds: 3));
    
    // 9. Complete the trip
    await db.completeTrip(tripId);
    
    // 10. Final State Verification
    final finalTrip = await db.getTrip(tripId);
    expect(finalTrip!['status'], 'completed');
    
    // Go offline cleanup
    await db.setDriverStatus(driverId, false);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
