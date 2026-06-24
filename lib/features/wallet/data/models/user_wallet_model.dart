import 'package:equatable/equatable.dart';

/// Maps exactly to DB table: user_wallets
/// Columns: id, balance, total_spent, total_topped_up, updated_at
/// Note: id = user.id (same UUID)
class UserWalletModel extends Equatable {
  final String id; // same as user_id
  final double balance;
  final double totalSpent;
  final double totalToppedUp;
  final DateTime updatedAt;

  const UserWalletModel({
    required this.id,
    required this.balance,
    required this.totalSpent,
    required this.totalToppedUp,
    required this.updatedAt,
  });

  factory UserWalletModel.fromJson(Map<String, dynamic> json) {
    return UserWalletModel(
      id: json['id'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      totalToppedUp: (json['total_topped_up'] as num?)?.toDouble() ?? 0.0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'balance': balance,
        'total_spent': totalSpent,
        'total_topped_up': totalToppedUp,
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, balance, totalSpent, totalToppedUp, updatedAt];
}
