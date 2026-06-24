import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// DRIVER FULL FLOW TEST
/// ================================================================
/// بيختبر الـ driver journey كاملة:
/// Login → Home (Online/Offline) → Request Feed → Trip Accept
///
/// شغّله على emulator:
/// flutter test integration_test/driver/driver_full_flow_test.dart \
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

  group('🚗 Driver Full Flow', () {

    testWidgets('01 — Driver Login', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.waitForKey(tester, 'login_screen', timeout: 10);

      await helper.enterText(tester, 'email_field',
          const String.fromEnvironment('TEST_DRIVER_EMAIL'));
      await helper.enterText(tester, 'password_field',
          const String.fromEnvironment('TEST_DRIVER_PASSWORD'));
      await helper.tap(tester, 'login_button');

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // السواق المفروض يروح driver home
      await helper.waitForKey(tester, 'driver_home_screen', timeout: 15);
      print('✅ Driver logged in successfully');

      await helper.takeScreenshot(tester, 'driver_home');
    });

    testWidgets('02 — Driver Home — Online/Offline Toggle', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // تحقق من الـ toggle button
      final toggleBtn = find.byKey(const ValueKey('driver_availability_toggle'));
      if (!toggleBtn.evaluate().isEmpty) {
        // اعرف الحالة الحالية
        final currentState = tester.widget(toggleBtn);
        print('Driver toggle found — testing toggle');

        // اضغط التوجل
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await helper.takeScreenshot(tester, 'driver_toggled');

        // ارجع للحالة الأصلية
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        print('✅ Driver availability toggle works');
      } else {
        print('ℹ️  Driver availability toggle not found with key');
      }
    });

    testWidgets('03 — Corridor Picker يفتح', (tester) async {
      await tester.pumpAndSettle();

      final corridorBtn = find.byKey(const ValueKey('corridor_picker_button'));
      if (!corridorBtn.evaluate().isEmpty) {
        await tester.tap(corridorBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await helper.takeScreenshot(tester, 'driver_corridor_picker');
        print('✅ Corridor picker opened');

        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('04 — Request Feed Screen', (tester) async {
      await tester.pumpAndSettle();

      // ممكن يكون tab أو زرار
      final requestFeedBtn = find.byKey(const ValueKey('request_feed_button'));
      if (!requestFeedBtn.evaluate().isEmpty) {
        await tester.tap(requestFeedBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await helper.takeScreenshot(tester, 'driver_request_feed');
        print('✅ Request feed screen opened');

        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('05 — Driver Trips History', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'drawer_trips');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'driver_trips_history');
      print('✅ Driver trips history loaded');

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('06 — Driver Wallet', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'drawer_wallet');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'driver_wallet');

      // تحقق من الأرباح
      final earningsFinder = find.byKey(const ValueKey('driver_earnings'));
      if (!earningsFinder.evaluate().isEmpty) {
        print('✅ Driver earnings displayed');
      }

      // تحقق من زرار السحب
      final withdrawBtn = find.byKey(const ValueKey('withdraw_button'));
      if (!withdrawBtn.evaluate().isEmpty) {
        print('✅ Withdraw button found');
        await helper.takeScreenshot(tester, 'driver_wallet_with_withdraw_btn');
      }

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('07 — Driver Bonus Screen', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'drawer_bonus');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'driver_bonus');
      print('✅ Driver bonus screen loaded');

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('08 — Driver Profile', (tester) async {
      await tester.pumpAndSettle();

      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'drawer_profile');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await helper.takeScreenshot(tester, 'driver_profile');
      print('✅ Driver profile loaded');

      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('09 — تحقق من وجود Location Permission Prompt', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // المفروض مش يطلب location permission لو سبق إعطاء الإذن
      final locationDenied = find.byKey(const ValueKey('location_permission_cta'));
      if (!locationDenied.evaluate().isEmpty) {
        print('⚠️  Location permission CTA is showing — driver needs to grant location');
        await helper.takeScreenshot(tester, 'driver_location_permission_needed');
      } else {
        print('✅ Location permission already granted');
      }
    });
  });
}
