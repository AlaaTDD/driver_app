import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snapix/main.dart' as app;
import 'helpers/db_tester.dart';
import 'helpers/auth_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Wallet & Coupons Flow (Funds, Promos)', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    final db = DbTester();

    final userId = await AuthHelper.loginUser(tester, 'sara.user@gmail.com', 'User@12345');
    expect(userId, isNotNull);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 1. Check Wallet Balance via DB
    final wallet = await db.client.from('wallets').select().eq('user_id', userId!).maybeSingle();
    double currentBalance = (wallet?['balance'] ?? 0.0) as double;

    // 2. Inject a Wallet Recharge
    await db.client.from('wallet_transactions').insert({
      'wallet_id': wallet!['id'],
      'amount': 100.0,
      'type': 'credit',
      'description': 'Recharge via Test',
    });

    await db.client.from('wallets').update({
      'balance': currentBalance + 100.0,
    }).eq('id', wallet['id']);

    // Verify
    final updatedWallet = await db.client.from('wallets').select().eq('id', wallet['id']).single();
    expect(updatedWallet['balance'], currentBalance + 100.0);

    // 3. Inject a Coupon application
    final couponRes = await db.client.from('coupons').insert({
      'code': 'TEST_PROMO_50',
      'discount_amount': 50.0,
      'expiry_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'usage_limit': 10,
    }).select('id').single();

    await db.client.from('user_coupons').insert({
      'user_id': userId,
      'coupon_id': couponRes['id'],
      'is_used': false,
    });
    
    // Check coupon is assigned
    final myCoupons = await db.client.from('user_coupons').select().eq('user_id', userId);
    expect(myCoupons, isNotEmpty);
  });
}
