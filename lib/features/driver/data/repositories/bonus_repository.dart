import 'package:snapix/core/models/bonus_claim_request_model.dart';
import 'package:snapix/core/models/bonus_progress_model.dart';
import 'package:snapix/core/models/bonus_rule_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

/// Repository for driver bonus/incentive system.
/// Wraps the `bonus_rules`, `driver_bonus_ledger`, `driver_bonus_progress`,
/// `bonus_claim_requests` tables and related RPCs.
class BonusRepository {
  final _client = SupabaseService.client;
  static const _timeout = Duration(seconds: 15);

  /// Get the current driver's bonus progress for today.
  /// Uses the `get_my_bonus_progress` RPC.
  Future<BonusProgressModel> getMyBonusProgress([String? driverId]) async {
    try {
      final result =
          await _client.rpc('get_my_bonus_progress').timeout(_timeout);
      if (result is List && result.isNotEmpty) {
        return BonusProgressModel.fromJson(
          Map<String, dynamic>.from(result.first as Map),
        );
      }
      if (result is Map) {
        return BonusProgressModel.fromJson(Map<String, dynamic>.from(result));
      }
      return const BonusProgressModel();
    } catch (e) {
      if (driverId != null) {
        try {
          final result = await _client.rpc(
            'get_my_bonus_progress',
            params: {'p_driver_id': driverId},
          ).timeout(_timeout);
          if (result is List && result.isNotEmpty) {
            return BonusProgressModel.fromJson(
              Map<String, dynamic>.from(result.first as Map),
            );
          }
          if (result is Map) {
            return BonusProgressModel.fromJson(
              Map<String, dynamic>.from(result),
            );
          }
        } catch (fallbackError) {
          AppLogger.debug(
              '❌ BonusRepository.getMyBonusProgress fallback: $fallbackError');
        }
      }
      AppLogger.error('BonusRepository.getMyBonusProgress: $e');
      return const BonusProgressModel();
    }
  }

  /// Get active bonus rules applicable to the driver.
  Future<List<BonusRuleModel>> getActiveBonusRules({
    String? vehicleType,
    String? serviceAreaId,
  }) async {
    try {
      var query = _client
          .from('bonus_rules')
          .select(
              'id, name, name_ar, trigger_type, threshold, min_rating, bonus_amount, is_active, category_ids, service_area_id, starts_at, expires_at, created_at')
          .eq('is_active', true);

      final data =
          await query.order('threshold', ascending: true).timeout(_timeout);

      return (data as List)
          .whereType<Map>()
          .map((e) => BonusRuleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.error('BonusRepository.getActiveBonusRules: $e');
      return [];
    }
  }

  /// Get driver's bonus ledger history.
  Future<List<Map<String, dynamic>>> getBonusHistory(
    String driverId, {
    int limit = 20,
  }) async {
    try {
      final data = await _client
          .from('driver_bonus_ledger')
          .select(
              'id, driver_id, bonus_amount, awarded_at, bonus_rules(name, name_ar, trigger_type, bonus_amount)')
          .eq('driver_id', driverId)
          .order('awarded_at', ascending: false)
          .limit(limit)
          .timeout(_timeout);
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      AppLogger.error('BonusRepository.getBonusHistory: $e');
      return [];
    }
  }

  /// السائق يضغط "ابدأ" على تحدٍ معيّن. يستدعي RPC `start_bonus_challenge`
  /// الذي يُنشئ صف `driver_bonus_progress` ويسجّل نقطة البدء (trips_at_start،
  /// rating_at_start) خادمياً — الاحتساب اللاحق يعتمد على هذه اللحظة فقط.
  ///
  /// يُرجع `progress_id` عند النجاح لاستخدامه لاحقاً في [requestBonusClaim].
  Future<String> startBonusChallenge(String ruleId) async {
    try {
      final result = await _client.rpc('start_bonus_challenge',
          params: {'p_rule_id': ruleId}).timeout(_timeout);

      final map = _asResultMap(result);
      if (map == null) {
        throw const ServerException('errorUnexpected');
      }

      if (map['success'] != true) {
        throw _mapRpcError(map['error'] as String?);
      }

      final progressId = map['progress_id']?.toString();
      if (progressId == null || progressId.isEmpty) {
        throw const ServerException('errorUnexpected');
      }
      return progressId;
    } on AppException {
      rethrow;
    } catch (e) {
      AppLogger.error('BonusRepository.startBonusChallenge: $e');
      throw const NetworkException();
    }
  }

  /// السائق يضغط "طلب استلام المكافأة" بعد اكتمال الشرط. يستدعي RPC
  /// `request_bonus_claim` الذي يتحقق خادمياً (وليس فقط من الواجهة) أن
  /// التحدي مكتمل فعلاً قبل قبول الطلب، ثم يُنشئ صف `bonus_claim_requests`
  /// بحالة pending بانتظار موافقة الإدارة.
  Future<void> requestBonusClaim(String progressId) async {
    try {
      final result = await _client.rpc('request_bonus_claim',
          params: {'p_progress_id': progressId}).timeout(_timeout);

      final map = _asResultMap(result);
      if (map == null) {
        throw const ServerException('errorUnexpected');
      }

      if (map['success'] != true) {
        throw _mapRpcError(map['error'] as String?);
      }
    } on AppException {
      rethrow;
    } catch (e) {
      AppLogger.error('BonusRepository.requestBonusClaim: $e');
      throw const NetworkException();
    }
  }

  /// طلبات استلام المكافآت الخاصة بالسائق (كل الحالات: pending/approved/rejected).
  Future<List<BonusClaimRequestModel>> getMyBonusClaims(
    String driverId, {
    int limit = 20,
  }) async {
    try {
      final data = await _client
          .from('bonus_claim_requests')
          .select(
              'id, bonus_rule_id, driver_bonus_progress_id, bonus_amount, trips_counted, status, requested_at, reviewed_at, rejection_reason')
          .eq('driver_id', driverId)
          .order('requested_at', ascending: false)
          .limit(limit)
          .timeout(_timeout);
      return (data as List)
          .whereType<Map>()
          .map((e) =>
              BonusClaimRequestModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.error('BonusRepository.getMyBonusClaims: $e');
      return [];
    }
  }

  /// دالة RPC المُنفَّذة عبر Supabase قد تُرجع jsonb كـ Map مباشرة، أو كـ List
  /// يحوي عنصراً واحداً (سلوك بعض إصدارات postgrest-dart مع jsonb scalar).
  /// هذه دالة موحَّدة لتطبيع الاستجابة، بنفس النمط المتبع في
  /// [getMyBonusProgress] أعلاه.
  Map<String, dynamic>? _asResultMap(Object? result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return null;
  }

  /// يحوّل كود الخطأ النصي القادم من RPC (jsonb 'error' field) إلى
  /// AppException مناسب، ليتعامل معه ErrorMapper بنفس نمط بقية المشروع.
  AppException _mapRpcError(String? errorCode) {
    switch (errorCode) {
      case 'unauthorized':
      case 'not_a_driver':
        return const AuthException('errorUnauthorized');
      case 'rule_not_available':
        return const NotFoundException('errorRuleNotAvailable');
      case 'already_claimed_this_period':
        return const ValidationException('errorAlreadyClaimedThisPeriod');
      case 'progress_not_found':
        return const NotFoundException('errorProgressNotFound');
      case 'challenge_not_completed':
        return const ValidationException('errorChallengeNotCompleted');
      case 'rule_not_found':
        return const NotFoundException('errorRuleNotFound');
      default:
        return const ServerException('errorUnexpected');
    }
  }
}
