import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// AUTHENTICATION TESTS
/// ================================================================
/// يغطي هذا الملف جميع الحالات المتعلقة بتسجيل الدخول وإنشاء الحساب
/// واستعادة كلمة المرور وتسجيل الخروج.
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

  group('🔐 Auth Module Tests', () {

    testWidgets('01 — Invalid Login shows validation errors', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // انتظار اختفاء الـ splash screen
      await helper.waitForKey(tester, 'splash_screen', timeout: 10);
      await helper.waitForKey(tester, 'login_screen', timeout: 5);

      // ضغط زر الدخول بدون إدخال بيانات
      await helper.tapKey(tester, 'login_button');
      await tester.pumpAndSettle();

      // التأكد من ظهور رسائل خطأ
      expect(find.byKey(const ValueKey('email_error_text')), findsOneWidget);
      expect(find.byKey(const ValueKey('password_error_text')), findsOneWidget);
    });

    testWidgets('02 — Navigate to Signup and validation', (tester) async {
      await tester.pumpAndSettle();

      // الذهاب لصفحة التسجيل
      await helper.tapKey(tester, 'go_to_signup_button');
      await tester.pumpAndSettle();

      await helper.waitForKey(tester, 'signup_screen', timeout: 5);

      // اختيار "راكب" من شاشة اختيار نوع الحساب للوصول لشاشة تسجيل
      // حساب الراكب الفعلية (signup_screen هي شاشة اختيار النوع فقط،
      // وليست شاشة التسجيل نفسها).
      await helper.tapKey(tester, 'register_as_user_card');
      await tester.pumpAndSettle();
      await helper.waitForKey(tester, 'register_user_screen', timeout: 5);

      // تجربة الإرسال بدون بيانات
      await helper.tapKey(tester, 'signup_button');
      await tester.pumpAndSettle();

      // التحقق من ظهور أخطاء الـ Validation
      expect(find.byKey(const ValueKey('name_error_text')), findsOneWidget);
      expect(find.byKey(const ValueKey('phone_error_text')), findsOneWidget);
      expect(find.byKey(const ValueKey('email_error_text')), findsOneWidget);
      
      // التقاط صورة للتأكيد
      await helper.takeScreenshot(tester, 'signup_validation_errors');

      // العودة لصفحة الدخول (عبر شاشة اختيار النوع أولاً، ثم صفحة الدخول)
      await helper.tapKey(tester, 'back_button');
      await tester.pumpAndSettle();
      await helper.tapKey(tester, 'go_to_login_button');
      await tester.pumpAndSettle();
    });

    testWidgets('03 — Forgot Password flow', (tester) async {
      await tester.pumpAndSettle();

      // الضغط على نسيان كلمة المرور
      await helper.tapKey(tester, 'forgot_password_button');
      await tester.pumpAndSettle();

      await helper.waitForKey(tester, 'forgot_password_screen', timeout: 5);

      // إدخال الإيميل
      await helper.enterText(tester, 'reset_email_field', 'test@driverr.com');
      await helper.tapKey(tester, 'send_reset_link_button');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // التحقق من ظهور رسالة نجاح
      expect(find.byKey(const ValueKey('reset_success_message')), findsOneWidget);
      await helper.takeScreenshot(tester, 'forgot_password_success');

      // العودة
      await tester.pageBack();
      await tester.pumpAndSettle();
    });

    testWidgets('04 — Successful Login with valid credentials', (tester) async {
      await tester.pumpAndSettle();

      await helper.waitForKey(tester, 'login_screen', timeout: 5);

      await helper.enterText(tester, 'email_field', const String.fromEnvironment('TEST_USER_EMAIL'));
      await helper.enterText(tester, 'password_field', const String.fromEnvironment('TEST_USER_PASSWORD'));
      await helper.tapKey(tester, 'login_button');

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // التأكد من الوصول للصفحة الرئيسية
      await helper.waitForKey(tester, 'user_home_screen', timeout: 10);
      print('✅ Successful login verified');
    });

  });
}
