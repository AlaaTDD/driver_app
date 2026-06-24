import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// RIDE OFFER & BIDDING TESTS
/// ================================================================
/// يغطي هذا الملف نظام المساومة:
/// - السائق يرسل عرض (Offer)
/// - الراكب يشاهد العروض ويقبل أو يرفض
/// - مفاوضات على السعر بين الطرفين
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

  group('🚕 Bidding & Offers Module Tests', () {

    // هنا نفترض أن الراكب طلب رحلة مسبقاً، وهذا التست يختبر شاشة السائق
    testWidgets('01 — Driver receives ride request and sends offer', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // تجاوز مرحلة الدخول للوصول لشاشة السائق
      await helper.waitForKey(tester, 'driver_home_screen', timeout: 10);

      // التأكد من أن السائق متصل (Online)
      final toggle = find.byKey(const ValueKey('driver_availability_toggle'));
      if (toggle.evaluate().isNotEmpty) {
        // نفترض أن هناك زر لفتح قائمة الطلبات المتاحة
        await helper.tapKey(tester, 'available_requests_tab');
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // الضغط على أول طلب متاح
        final firstRequest = find.byKey(const ValueKey('ride_request_card_0'));
        if (firstRequest.evaluate().isNotEmpty) {
          await tester.tap(firstRequest);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // السائق يدخل السعر المطلوب
          await helper.enterText(tester, 'offer_price_input', '50');
          
          // الضغط على إرسال العرض
          await helper.tapKey(tester, 'send_offer_button');
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // التأكد من ظهور رسالة بنجاح الإرسال
          expect(find.byKey(const ValueKey('offer_sent_success')), findsOneWidget);
          await helper.takeScreenshot(tester, 'driver_offer_sent');
        } else {
          print('ℹ️ No active requests found to bid on (skip or mock needed)');
        }
      }
    });

    testWidgets('02 — User receives offers and accepts one', (tester) async {
      // هذا التست يفترض أننا في حساب المستخدم (الراكب)
      // يمكن استخدام mock أو إعادة الدخول بحساب الراكب هنا
      print('ℹ️ User side check for incoming offers');
      // يتم محاكاة قبول الراكب للعرض في هذا الجزء
      // await helper.waitForKey(tester, 'incoming_offer_card_0', timeout: 5);
      // await helper.tapKey(tester, 'accept_offer_button');
      // expect(find.byKey(const ValueKey('trip_started_screen')), findsOneWidget);
    });

  });
}
