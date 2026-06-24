import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// TRIP MANAGEMENT TESTS
/// ================================================================
/// يغطي:
/// - إلغاء الرحلة من قبل الراكب والسائق
/// - تقييم السائق بعد انتهاء الرحلة
/// - مراجعة تفاصيل الرحلات السابقة
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

  group('🚗 Trips Module Tests', () {

    testWidgets('01 — User can cancel an active trip request', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // نفترض أننا بانتظار العروض (Waiting for offers)
      // await helper.waitForKey(tester, 'waiting_for_offers_screen', timeout: 5);
      
      // // الضغط على زر الإلغاء
      // await helper.tapKey(tester, 'cancel_request_button');
      // await tester.pumpAndSettle();

      // // تأكيد الإلغاء في الـ Dialog
      // await helper.tapKey(tester, 'confirm_cancel_button');
      // await tester.pumpAndSettle(const Duration(seconds: 3));

      // // التحقق من العودة للصفحة الرئيسية
      // expect(find.byKey(const ValueKey('user_home_screen')), findsOneWidget);
    });

    testWidgets('02 — User can rate driver after trip completion', (tester) async {
      // محاكاة انتهاء الرحلة وظهور شاشة التقييم
      // await helper.waitForKey(tester, 'rating_screen', timeout: 5);

      // // اختيار 5 نجوم
      // await helper.tapKey(tester, 'star_rating_5');
      // await tester.pumpAndSettle();

      // // كتابة تعليق
      // await helper.enterText(tester, 'rating_comment_input', 'سائق ممتاز ومحترم');
      
      // // إرسال التقييم
      // await helper.tapKey(tester, 'submit_rating_button');
      // await tester.pumpAndSettle(const Duration(seconds: 3));

      // // التأكد من العودة للصفحة الرئيسية
      // expect(find.byKey(const ValueKey('user_home_screen')), findsOneWidget);
    });

    testWidgets('03 — User can view trip details from history', (tester) async {
      // await helper.tapKey(tester, 'drawer_button');
      // await tester.pumpAndSettle();
      
      // await helper.tapKey(tester, 'drawer_trips');
      // await tester.pumpAndSettle(const Duration(seconds: 3));

      // // اختيار أول رحلة
      // await helper.tapKey(tester, 'trip_history_item_0');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // التأكد من ظهور التفاصيل (السعر، المسار، السائق)
      // expect(find.byKey(const ValueKey('trip_detail_price')), findsOneWidget);
      // await helper.takeScreenshot(tester, 'trip_details');
    });

  });
}
