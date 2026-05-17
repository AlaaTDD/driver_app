import 'package:equatable/equatable.dart';

// ─── ENUMs matching DB ─────────────────────────────────────────────────────

enum WalletTransactionType {
  tripEarning,
  tripPayment,
  withdrawal,
  withdrawalRefund,
  topUp,
  refund,
  bonus,
  penalty,
  couponSubsidy,
  adjustment;

  static WalletTransactionType fromString(String? s) {
    switch (s) {
      case 'trip_earning':
      case 'trip_fare':
        return WalletTransactionType.tripEarning;
      case 'trip_payment':
        return WalletTransactionType.tripPayment;
      case 'withdrawal':
        return WalletTransactionType.withdrawal;
      case 'withdrawal_refund':
        return WalletTransactionType.withdrawalRefund;
      case 'top_up':
        return WalletTransactionType.topUp;
      case 'refund':
        return WalletTransactionType.refund;
      case 'bonus':
        return WalletTransactionType.bonus;
      case 'penalty':
        return WalletTransactionType.penalty;
      case 'coupon_subsidy':
        return WalletTransactionType.couponSubsidy;
      default:
        return WalletTransactionType.adjustment;
    }
  }

  String toDbString() {
    switch (this) {
      case WalletTransactionType.tripEarning:
        return 'trip_earning';
      case WalletTransactionType.tripPayment:
        return 'trip_payment';
      case WalletTransactionType.withdrawal:
        return 'withdrawal';
      case WalletTransactionType.withdrawalRefund:
        return 'withdrawal_refund';
      case WalletTransactionType.topUp:
        return 'top_up';
      case WalletTransactionType.refund:
        return 'refund';
      case WalletTransactionType.bonus:
        return 'bonus';
      case WalletTransactionType.penalty:
        return 'penalty';
      case WalletTransactionType.couponSubsidy:
        return 'coupon_subsidy';
      case WalletTransactionType.adjustment:
        return 'adjustment';
    }
  }
}

enum WalletTransactionStatus {
  pending,
  completed,
  failed,
  reversed;

  static WalletTransactionStatus fromString(String? s) {
    switch (s) {
      case 'pending':
        return WalletTransactionStatus.pending;
      case 'failed':
        return WalletTransactionStatus.failed;
      case 'reversed':
        return WalletTransactionStatus.reversed;
      default:
        return WalletTransactionStatus.completed;
    }
  }
}

// ─── Model ─────────────────────────────────────────────────────────────────

/// Maps exactly to DB table: wallet_transactions
/// Columns: id, wallet_id, wallet_type, type (ENUM), amount, balance_before,
///          balance_after, reference_id, reference_type, status (ENUM),
///          description, metadata (jsonb), created_at
class WalletTransactionModel extends Equatable {
  final String id;
  final String walletId;
  final String walletType; // 'driver' | 'user'
  final WalletTransactionType type;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? referenceId;
  final String? referenceType;
  final WalletTransactionStatus status;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.walletType,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.referenceId,
    this.referenceType,
    required this.status,
    this.description,
    this.metadata,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      walletType: json['wallet_type'] as String? ?? 'driver',
      type: WalletTransactionType.fromString(json['type'] as String?),
      amount: (json['amount'] as num).toDouble(),
      balanceBefore: (json['balance_before'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      status: WalletTransactionStatus.fromString(json['status'] as String?),
      description: json['description'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Is this a credit (money in) or debit (money out)?
  bool get isCredit => [
        WalletTransactionType.tripEarning,
        WalletTransactionType.topUp,
        WalletTransactionType.refund,
        WalletTransactionType.bonus,
        WalletTransactionType.couponSubsidy,
        WalletTransactionType.withdrawalRefund,
      ].contains(type);

  bool get isDebit => !isCredit;

  @override
  List<Object?> get props => [
        id,
        walletId,
        walletType,
        type,
        amount,
        balanceBefore,
        balanceAfter,
        referenceId,
        referenceType,
        status,
        description,
        createdAt,
      ];
}
