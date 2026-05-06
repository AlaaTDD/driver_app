class DriverWalletModel {
  final String driverId;
  final double balance;
  final double totalEarned;
  final double totalWithdrawn;
  final double pendingWithdrawal;
  final double commissionRate;
  final double earningsLastWeek;
  final double earningsLast30Days;
  final int completedTrips;

  const DriverWalletModel({
    required this.driverId,
    required this.balance,
    required this.totalEarned,
    required this.totalWithdrawn,
    required this.pendingWithdrawal,
    required this.commissionRate,
    required this.earningsLastWeek,
    required this.earningsLast30Days,
    required this.completedTrips,
  });

  factory DriverWalletModel.fromJson(Map<String, dynamic> json) {
    return DriverWalletModel(
      driverId: json['driver_id'] as String,
      balance: (json['available_balance'] as num?)?.toDouble() ?? 0,
      totalEarned: (json['total_earnings'] as num?)?.toDouble() ?? 0,
      totalWithdrawn: (json['total_withdrawn'] as num?)?.toDouble() ?? 0,
      pendingWithdrawal: (json['pending_withdrawal'] as num?)?.toDouble() ?? 0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.15,
      earningsLastWeek: (json['earnings_this_week'] as num?)?.toDouble() ?? 0,
      earningsLast30Days: (json['earnings_last_30_days'] as num?)?.toDouble() ?? 0,
      completedTrips: (json['completed_trips'] as int?) ?? 0,
    );
  }

  /// نصيب المنصة من الأرباح الكلية
  double get totalPlatformFees => totalEarned * commissionRate / (1 - commissionRate);

  /// نسبة نصيب السائق
  double get driverSharePercentage => (1 - commissionRate) * 100;
}
