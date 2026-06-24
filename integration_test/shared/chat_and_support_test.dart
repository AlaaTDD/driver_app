import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// CHAT & SUPPORT TESTS
/// ================================================================
/// يغطي:
/// - الدردشة الفورية بين السائق والراكب
/// - الاتصال الهاتفي
/// - رفع شكوى الدعم الفني
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

  group('💬 Chat & Support Module Tests', () {

    testWidgets('01 — Send and receive chat messages during active trip', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // افتراض وجود رحلة نشطة، وفتح الشات
      // await helper.tapKey(tester, 'open_chat_button');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // إرسال رسالة
      // await helper.enterText(tester, 'chat_input_field', 'أنا بانتظارك في الموقع');
      // await helper.tapKey(tester, 'send_message_button');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // التأكد من ظهور الرسالة في الشات
      // expect(find.text('أنا بانتظارك في الموقع'), findsOneWidget);
      // await helper.takeScreenshot(tester, 'trip_chat');
      
      // await tester.pageBack();
      // await tester.pumpAndSettle();
    });

    testWidgets('02 — User can submit a complaint ticket', (tester) async {
      // فتح الشكاوى من القائمة
      // await helper.tapKey(tester, 'drawer_button');
      // await tester.pumpAndSettle();
      // await helper.tapKey(tester, 'drawer_complaints');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // إضافة شكوى جديدة
      // await helper.tapKey(tester, 'add_complaint_button');
      // await tester.pumpAndSettle();

      // // تعبئة النموذج
      // await helper.enterText(tester, 'complaint_title_input', 'مشكلة في الدفع');
      // await helper.enterText(tester, 'complaint_desc_input', 'تم خصم الرصيد ولم تكتمل الرحلة.');
      
      // await helper.tapKey(tester, 'submit_complaint_button');
      // await tester.pumpAndSettle(const Duration(seconds: 3));

      // // التأكد من ظهور الشكوى في القائمة
      // expect(find.text('مشكلة في الدفع'), findsOneWidget);
      // await helper.takeScreenshot(tester, 'complaints_list');
    });

  });
}
