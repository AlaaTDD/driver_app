import 'package:snapix/core/models/driver_earnings_model.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/wallet_transaction_model.dart';
import '../models/withdrawal_request_model.dart';
import '../models/user_wallet_model.dart';
import '../models/driver_wallet_model.dart';
import '../../../../core/utils/uuid_helper.dart';
import 'package:snapix/core/utils/app_logger.dart';

class WalletRepository {
  final _client = SupabaseService.client;

  /// جلب ملخص أرباح السائق (merged from view + detailed function)
  Future<DriverEarningsModel> getDriverEarningsSummary(String driverId) async {
    try {
      // Fetch from both data sources in parallel
      final results = await Future.wait([
        // Primary: the summary view (balance, total_earnings, pending, etc.)
        _client
            .from('driver_earnings_summary')
            .select()
            .eq('driver_id', driverId)
            .single(),
        // Secondary: the detailed function (earnings_7d, earnings_30d)
        _client.rpc('get_driver_earnings_detailed', params: {
          'p_driver_id': driverId,
        }).then((res) {
          if (res is List && res.isNotEmpty) return res.first;
          if (res is Map) return res;
          return <String, dynamic>{};
        }).catchError((_) => <String, dynamic>{}),
      ]);

      final summaryData = Map<String, dynamic>.from(results[0] as Map);
      final detailedData = results[1] as Map<String, dynamic>? ?? {};

      // Prefer the summary view because it is based on trips.driver_earnings.
      // The legacy detailed RPC may return gross trip price, so only use it
      // when the summary value is absent.
      if (!summaryData.containsKey('earnings_7d') &&
          detailedData.containsKey('earnings_7d')) {
        summaryData['earnings_7d'] = detailedData['earnings_7d'];
      }
      if (!summaryData.containsKey('earnings_30d') &&
          detailedData.containsKey('earnings_30d')) {
        summaryData['earnings_30d'] = detailedData['earnings_30d'];
      }

      return DriverEarningsModel.fromJson(summaryData);
    } catch (e) {
      AppLogger.error('WalletRepository.getDriverEarningsSummary: $e');
      return const DriverEarningsModel();
    }
  }

  /// Get typed transaction history
  Future<List<WalletTransactionModel>> getTransactionHistory({
    required String userId,
    required String walletType, // 'driver' or 'user'
    int limit = 20,
    DateTime? before,
  }) async {
    try {
      var filterBuilder = _client
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', userId)
          .eq('wallet_type', walletType);

      if (before != null) {
        filterBuilder =
            filterBuilder.lt('created_at', before.toIso8601String());
      }

      final result = await filterBuilder
          .order('created_at', ascending: false)
          .limit(limit);

      return (result as List)
          .map((e) =>
              WalletTransactionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.error('WalletRepository.getTransactionHistory: $e');
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
    final params = <String, dynamic>{
      'p_driver_id': driverId,
      'p_amount': amount,
      'p_payment_method': paymentMethod,
      'p_account_details': accountDetails,
      'p_idempotency_key': idempotencyKey ?? UuidHelper.generateV4(),
    };

    final result = await _client.rpc(
      'request_driver_withdrawal',
      params: params,
    );
    return (result as Map<String, dynamic>?) ??
        {'success': false, 'error': 'unknown_error'};
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

      final result = await filterBuilder.order('created_at', ascending: false);

      return (result as List)
          .map((e) =>
              WithdrawalRequestModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.error('WalletRepository.getWithdrawalRequests: $e');
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
      final data =
          await _client.from('user_wallets').select().eq('id', userId).single();
      return UserWalletModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      AppLogger.error('WalletRepository.getUserWallet: $e');
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
