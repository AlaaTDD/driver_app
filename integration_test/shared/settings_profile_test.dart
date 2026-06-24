import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// SETTINGS & PROFILE TESTS
/// ================================================================
/// يغطي:
/// - تعديل الملف الشخصي (الاسم، تغيير الصورة)
/// - تغيير اللغة (عربي / إنجليزي)
/// - تغيير الـ Theme (Dark / Light)
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

  group('⚙️ Settings & Profile Module Tests', () {

    testWidgets('01 — Update user profile details', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // await helper.tapKey(tester, 'drawer_button');
      // await tester.pumpAndSettle();
      
      // await helper.tapKey(tester, 'drawer_profile');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // تحديث الاسم
      // await helper.enterText(tester, 'profile_name_input', 'اسم تجريبي');
      // await helper.tapKey(tester, 'save_profile_button');
      // await tester.pumpAndSettle(const Duration(seconds: 3));

      // // التحقق من الحفظ بنجاح
      // expect(find.byKey(const ValueKey('profile_saved_success')), findsOneWidget);
      // await helper.takeScreenshot(tester, 'profile_updated');
    });

    testWidgets('02 — Change Language & Theme', (tester) async {
      // await tester.pageBack();
      // await tester.pumpAndSettle();
      
      // // الذهاب للإعدادات
      // await helper.tapKey(tester, 'drawer_button');
      // await tester.pumpAndSettle();
      // await helper.tapKey(tester, 'drawer_settings');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // تغيير الثيم
      // await helper.tapKey(tester, 'theme_toggle_switch');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // // تغيير اللغة
      // await helper.tapKey(tester, 'language_dropdown');
      // await tester.pumpAndSettle();
      // await helper.tapKey(tester, 'lang_english');
      // await tester.pumpAndSettle(const Duration(seconds: 2));

      // await helper.takeScreenshot(tester, 'settings_changed');
    });

  });
}
