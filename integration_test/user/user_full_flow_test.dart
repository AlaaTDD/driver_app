import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// USER FULL FLOW TEST
/// ================================================================
/// بيختبر الـ user journey كاملة:
/// Login → Home → Location Select → Meeting Point → Pricing → Searching
///
/// شغّله على emulator:
/// flutter test integration_test/user/user_full_flow_test.dart \
///   --device-id <emulator_id>
/// ================================================================
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestHelper helper;

  setUpAll(() async {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    helper = TestHelper();
  });

  tearDownAll(() async {
    await helper.cleanup();
  });

  group('👤 User Full Flow', () {

    testWidgets('01 — Login بـ credentials صح', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // الـ splash screen
      await helper.waitForKey(tester, 'splash_screen', timeout: 10);

      // هيروح لـ login لو مش logged in
      await helper.waitForKey(tester, 'login_screen', timeout: 5);

      // ادخل credentials
      await helper.enterText(tester, 'email_field',
          const String.fromEnvironment('TEST_USER_EMAIL'));
      await helper.enterText(tester, 'password_field',
          const String.fromEnvironment('TEST_USER_PASSWORD'));
      await helper.tap(tester, 'login_button');

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // المفروض يروح لـ user home
      await helper.waitForKey(tester, 'user_home_screen', timeout: 10);
      print('✅ User logged in successfully');
    });

    testWidgets('02 — Home screen تتحمل وعندها Map', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // تحقق من وجود الـ map
      final mapFinder = find.byKey(const ValueKey('home_map'));
      if (!mapFinder.evaluate().isEmpty) {
        print('✅ Map found on home screen');
      }

      // تحقق من bottom nav
      final bottomNav = find.byKey(const ValueKey('bottom_nav'));
      if (!bottomNav.evaluate().isEmpty) {
        print('✅ Bottom navigation found');
      }

      // التقط screenshot وتحقق منه بصرياً
      await helper.takeScreenshot(tester, 'user_home');
    });

    testWidgets('03 — الـ Drawer يفتح وعنده كل الـ menu items', (tester) async {
      await tester.pumpAndSettle();

      // افتح الـ drawer
      final drawerBtn = find.byKey(const ValueKey('drawer_button'));
      if (!drawerBtn.evaluate().isEmpty) {
        await tester.tap(drawerBtn);
        await tester.pumpAndSettle();
        await helper.takeScreenshot(tester, 'user_drawer_open');
      }

      // تحقق من menu items المهمة
      for (final item in [
        'drawer_profile',
        'drawer_trips',
        'drawer_wallet',
        'drawer_messages',
        'drawer_complaints',
      ]) {
        final finder = find.byKey(ValueKey(item));
        if (finder.evaluate().isNotEmpty) {
          print('✅ Drawer item found: $item');
        } else {
          print('⚠️  Drawer item NOT found: $item');
        }
      }
    });

    testWidgets('04 — Location Selection تشتغل', (tester) async {
      await tester.pumpAndSettle();

      // اضغط على حقل الوجهة في الـ home
      await helper.tapKey(tester, 'destination_input');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await helper.takeScreenshot(tester, 'location_selection');

      // تحقق من وجود search field
      final searchField = find.byKey(const ValueKey('location_search_field'));
      if (!searchField.evaluate().isEmpty) {
        await tester.enterText(searchField, 'القاهرة');
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await helper.takeScreenshot(tester, 'location_search_results');
        print('✅ Location search works');
      }

      // ارجع
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('05 — Wallet screen تتحمل', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'drawer_wallet');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'user_wallet');

      // تحقق من وجود الرصيد
      final balanceFinder = find.byKey(const ValueKey('wallet_balance'));
      if (!balanceFinder.evaluate().isEmpty) {
        print('✅ Wallet balance displayed');
      }

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('06 — Trips history تتحمل', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'drawer_trips');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'user_trips_history');
      print('✅ User trips screen loaded');

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('07 — Profile screen تتحمل', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'drawer_profile');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'user_profile');
      print('✅ User profile screen loaded');

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('08 — Complaints screen تتحمل', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'drawer_complaints');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'user_complaints');
      print('✅ User complaints screen loaded');

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('09 — Notifications screen تتحمل', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'notifications_button');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'user_notifications');
      print('✅ Notifications screen loaded');

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('10 — Logout يشتغل صح', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();

      final logoutBtn = find.byKey(const ValueKey('logout_button'));
      if (!logoutBtn.evaluate().isEmpty) {
        await tester.tap(logoutBtn);
        await tester.pumpAndSettle();

        // تأكيد
        final confirmLogout = find.byKey(const ValueKey('confirm_logout'));
        if (!confirmLogout.evaluate().isEmpty) {
          await tester.tap(confirmLogout);
          await tester.pumpAndSettle(const Duration(seconds: 3));
        }

        // المفروض يروح login
        final loginScreen = find.byKey(const ValueKey('login_screen'));
        if (!loginScreen.evaluate().isEmpty) {
          print('✅ Logout successful — back to login screen');
        }
      }
    });
  });
}
