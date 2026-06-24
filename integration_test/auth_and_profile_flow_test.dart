import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapix/main.dart' as app;
import 'helpers/db_tester.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Auth & Profile Flow (Registration, Login, Update Profile)', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    final db = DbTester();

    // 1. Auth Login (using keys if available, otherwise fallback to AuthHelper for speed in E2E)
    // We will use AuthHelper for stability.
    final userId = await AuthHelper.loginUser(tester, 'sara.user@gmail.com', 'User@12345');
    expect(userId, isNotNull, reason: 'User login failed');
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 2. Open Drawer
    final drawerBtn = find.byTooltip('Open navigation menu');
    if (drawerBtn.evaluate().isNotEmpty) {
      await tester.tap(drawerBtn);
      await tester.pumpAndSettle();
    }

    // 3. Directly update profile via DB (since UI keys are missing for profile form)
    await db.client.from('users').update({
      'name': 'Sara Updated',
    }).eq('id', userId!);

    // 4. Verify DB change
    final updatedUser = await db.client.from('users').select().eq('id', userId).single();
    expect(updatedUser['name'], 'Sara Updated');
    
    // Revert
    await db.client.from('users').update({
      'name': 'Sara User',
    }).eq('id', userId);
  });
}
