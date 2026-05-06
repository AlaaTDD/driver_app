
import 'package:equatable/equatable.dart';

// ─── ENUMs matching DB ─────────────────────────────────────────────────────

enum WithdrawalMethod {
  bankTransfer,
  vodafoneCash,
  instapay,
  orangeMoney;

  static WithdrawalMethod fromString(String? s) {
    switch (s) {
      case 'bank_transfer':   return WithdrawalMethod.bankTransfer;
      case 'vodafone_cash':   return WithdrawalMethod.vodafoneCash;
      case 'instapay':        return WithdrawalMethod.instapay;
      default:                return WithdrawalMethod.orangeMoney;
    }
  }

  String toDbString() {
    switch (this) {
      case WithdrawalMethod.bankTransfer: return 'bank_transfer';
      case WithdrawalMethod.vodafoneCash: return 'vodafone_cash';
      case WithdrawalMethod.instapay:     return 'instapay';
      case WithdrawalMethod.orangeMoney:  return 'orange_money';
    }
  }
}

enum WithdrawalStatus {
  pending,
  approved,
  processing,
  completed,
  rejected,
  cancelled;

  static WithdrawalStatus fromString(String? s) {
    switch (s) {
      case 'approved':    return WithdrawalStatus.approved;
      case 'processing':  return WithdrawalStatus.processing;
      case 'completed':   return WithdrawalStatus.completed;
      case 'rejected':    return WithdrawalStatus.rejected;
      case 'cancelled':   return WithdrawalStatus.cancelled;
      default:            return WithdrawalStatus.pending;
    }
  }
}

// ─── Model ─────────────────────────────────────────────────────────────────

/// Maps exactly to DB table: withdrawal_requests
/// Columns: id, driver_id, amount, status (ENUM), idempotency_key,
///          payment_method (ENUM), account_details (jsonb), admin_id,
///          rejection_reason, admin_notes, processed_at, transaction_id,
///          created_at, updated_at
class WithdrawalRequestModel extends Equatable {
  final String id;
  final String driverId;
  final double amount;
  final WithdrawalStatus status;
  final String idempotencyKey;
  final WithdrawalMethod paymentMethod;
  final Map<String, dynamic> accountDetails;
  final String? adminId;
  final String? rejectionReason;
  final String? adminNotes;
  final DateTime? processedAt;
  final String? transactionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WithdrawalRequestModel({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.status,
    required this.idempotencyKey,
    required this.paymentMethod,
    required this.accountDetails,
    this.adminId,
    this.rejectionReason,
    this.adminNotes,
    this.processedAt,
    this.transactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WithdrawalRequestModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequestModel(
      id:               json['id'] as String,
      driverId:         json['driver_id'] as String,
      amount:           (json['amount'] as num).toDouble(),
      status:           WithdrawalStatus.fromString(json['status'] as String?),
      idempotencyKey:   json['idempotency_key'] as String? ?? '',
      paymentMethod:    WithdrawalMethod.fromString(json['payment_method'] as String?),
      accountDetails:   Map<String, dynamic>.from(json['account_details'] as Map? ?? {}),
      adminId:          json['admin_id'] as String?,
      rejectionReason:  json['rejection_reason'] as String?,
      adminNotes:       json['admin_notes'] as String?,
      processedAt:      json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      transactionId:    json['transaction_id'] as String?,
      createdAt:        DateTime.parse(json['created_at'] as String),
      updatedAt:        DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPending   => status == WithdrawalStatus.pending;
  bool get isCompleted => status == WithdrawalStatus.completed;
  bool get isRejected  => status == WithdrawalStatus.rejected;

  @override
  List<Object?> get props => [
    id, driverId, amount, status, paymentMethod,
    accountDetails, rejectionReason, processedAt, createdAt,
  ];
}
