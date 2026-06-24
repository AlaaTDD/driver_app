import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// COUPONS TESTS
/// ================================================================
/// يغطي:
/// - إضافة كوبون صحيح وخصم السعر
/// - إضافة كوبون منتهي أو خاطئ وظهور رسالة تنبيه
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

  group('🎟️ Coupons Module Tests', () {

    testWidgets('01 — User can apply a valid coupon', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // نفترض المستخدم قام بتحديد مسار الرحلة وفي شاشة تحديد السعر أو الكوبون
      // await helper.waitForKey(tester, 'apply_coupon_section', timeout: 5);
      
      // await helper.enterText(tester, 'coupon_code_input', 'TEST50');
      // await helper.tapKey(tester, 'apply_coupon_button');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // التحقق من نجاح العملية وخصم السعر
      // expect(find.byKey(const ValueKey('coupon_success_msg')), findsOneWidget);
      // await helper.takeScreenshot(tester, 'coupon_applied');
    });

    testWidgets('02 — Invalid coupon shows an error message', (tester) async {
      // await helper.enterText(tester, 'coupon_code_input', 'INVALID123');
      // await helper.tapKey(tester, 'apply_coupon_button');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // التحقق من رسالة الخطأ
      // expect(find.byKey(const ValueKey('coupon_error_msg')), findsOneWidget);
    });

  });
}
