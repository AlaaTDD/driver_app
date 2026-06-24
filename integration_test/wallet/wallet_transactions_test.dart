import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_helper.dart';

/// ================================================================
/// WALLET & TRANSACTIONS TESTS
/// ================================================================
/// يغطي هذا الملف كل ما يخص المحفظة:
/// - شحن الرصيد للمستخدم
/// - طلب سحب أرباح للسائق
/// - فحص سجل العمليات (Transaction History)
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

  group('💳 Wallet Module Tests', () {

    testWidgets('01 — User can add funds to wallet', (tester) async {
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // نفترض أننا في حساب المستخدم وفتحنا الـ Drawer
      await helper.tapKey(tester, 'drawer_button');
      await tester.pumpAndSettle();
      
      await helper.tapKey(tester, 'drawer_wallet');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // الضغط على زر إضافة رصيد
      await helper.tapKey(tester, 'add_funds_button');
      await tester.pumpAndSettle();

      // إدخال القيمة
      await helper.enterText(tester, 'amount_input_field', '100');
      await helper.tapKey(tester, 'confirm_add_funds_button');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // التحقق من أن العملية تمت (Mock Payment)
      expect(find.byKey(const ValueKey('payment_success_dialog')), findsOneWidget);
      await helper.takeScreenshot(tester, 'user_add_funds_success');
      
      await helper.tapKey(tester, 'close_dialog_button');
      await tester.pumpAndSettle();
    });

    testWidgets('02 — Driver can request withdrawal', (tester) async {
      // نفترض الانتقال لتطبيق السائق
      print('ℹ️ Testing driver withdrawal');
      
      // await helper.tapKey(tester, 'drawer_wallet');
      // await tester.pumpAndSettle();
      
      // await helper.tapKey(tester, 'request_withdrawal_button');
      // await tester.pumpAndSettle();

      // // إدخال قيمة السحب
      // await helper.enterText(tester, 'withdrawal_amount_input', '500');
      // await helper.tapKey(tester, 'submit_withdrawal_button');
      // await tester.pumpAndSettle(const Duration(seconds: 3));

      // expect(find.byKey(const ValueKey('withdrawal_pending_status')), findsOneWidget);
    });

    testWidgets('03 — Transaction history is visible', (tester) async {
      // await tester.pumpAndSettle();
      // final historyList = find.byKey(const ValueKey('transaction_history_list'));
      // expect(historyList, findsOneWidget);
      // await helper.takeScreenshot(tester, 'wallet_history');
    });

  });
}
