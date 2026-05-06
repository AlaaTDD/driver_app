import 'package:flutter/foundation.dart';
import '../../../../services/supabase_service.dart';
import '../models/wallet_transaction_model.dart';
import '../models/withdrawal_request_model.dart';
import '../models/user_wallet_model.dart';
import '../models/driver_wallet_model.dart';

class WalletRepository {
  final _client = SupabaseService.client;

  /// جلب ملخص أرباح السائق
  Future<Map<String, dynamic>> getDriverEarningsSummary(String driverId) async {
    final data = await _client
        .from('driver_earnings_summary')
        .select()
        .eq('driver_id', driverId)
        .single();
    return data;
  }

  /// Get typed transaction history
  Future<List<WalletTransactionModel>> getTransactionHistory({
    required String userId,
    int limit = 20,
    DateTime? before,
  }) async {
    try {
      var filterBuilder = _client
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', userId);

      if (before != null) {
        filterBuilder = filterBuilder.lt('created_at', before.toIso8601String());
      }

      final result = await filterBuilder
          .order('created_at', ascending: false)
          .limit(limit);

      return (result as List)
          .map((e) => WalletTransactionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ WalletRepository.getTransactionHistory: $e');
      return [];
    }
  }

  /// طلب السحب
  Future<Map<String, dynamic>> requestWithdrawal({
    required String driverId,
    required double amount,
    required String paymentMethod,
    required Map<String, dynamic> accountDetails,
    String? idempotencyKey,
  }) async {
    final result = await _client.rpc(
      'request_driver_withdrawal',
      params: {
        'p_driver_id': driverId,
        'p_amount': amount,
        'p_payment_method': paymentMethod,
        'p_account_details': accountDetails,
        'p_idempotency_key': idempotencyKey ?? DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    return (result as Map<String, dynamic>?) ?? {'success': false, 'error': 'unknown_error'};
  }

  /// Get typed withdrawal requests
  Future<List<WithdrawalRequestModel>> getWithdrawalRequests(
    String driverId, {
    String? status,
  }) async {
    try {
      var filterBuilder = _client
          .from('withdrawal_requests')
          .select()
          .eq('driver_id', driverId);

      if (status != null) {
        filterBuilder = filterBuilder.eq('status', status);
      }

      final result = await filterBuilder
          .order('created_at', ascending: false);

      return (result as List)
          .map((e) => WithdrawalRequestModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ WalletRepository.getWithdrawalRequests: $e');
      return [];
    }
  }

  /// Stream: مراقبة تغيرات محفظة السائق في الوقت الحقيقي
  Stream<DriverWalletModel?> watchDriverWallet(String driverId) {
    return _client
        .from('driver_wallets')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .map((rows) => rows.isNotEmpty
            ? DriverWalletModel.fromJson(Map<String, dynamic>.from(rows.first))
            : null);
  }

  /// جلب محفظة المستخدم
  Future<UserWalletModel?> getUserWallet(String userId) async {
    try {
      final data = await _client
          .from('user_wallets')
          .select()
          .eq('id', userId)
          .single();
      return UserWalletModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('❌ WalletRepository.getUserWallet: $e');
      return null;
    }
  }

  /// Stream: مراقبة تغيرات محفظة المستخدم في الوقت الحقيقي
  Stream<UserWalletModel?> watchUserWallet(String userId) {
    return _client
        .from('user_wallets')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isNotEmpty
            ? UserWalletModel.fromJson(Map<String, dynamic>.from(rows.first))
            : null);
  }
}
