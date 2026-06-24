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
    final rawId = json['driver_id'] ?? json['id'];
    assert(rawId != null,
        'DriverWalletModel.fromJson: neither driver_id nor id found in $json');
    return DriverWalletModel(
      driverId: rawId as String,
      // Handle both view alias ('available_balance') and direct table column ('balance')
      balance: (json['available_balance'] as num?)?.toDouble() ??
          (json['balance'] as num?)?.toDouble() ??
          0,
      totalEarned: (json['total_earnings'] as num?)?.toDouble() ??
          (json['total_earned'] as num?)?.toDouble() ??
          0,
      totalWithdrawn: (json['total_withdrawn'] as num?)?.toDouble() ?? 0,
      pendingWithdrawal: (json['pending_withdrawal'] as num?)?.toDouble() ?? 0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.15,
      // DB view returns 'earnings_7d' not 'earnings_this_week'
      earningsLastWeek: (json['earnings_7d'] as num?)?.toDouble() ??
          (json['earnings_this_week'] as num?)?.toDouble() ??
          0,
      // DB view returns 'earnings_30d' not 'earnings_last_30_days'
      earningsLast30Days: (json['earnings_30d'] as num?)?.toDouble() ??
          (json['earnings_last_30_days'] as num?)?.toDouble() ??
          0,
      completedTrips: (json['completed_trips'] as int?) ?? 0,
    );
  }

  DriverWalletModel copyWith({
    String? driverId,
    double? balance,
    double? totalEarned,
    double? totalWithdrawn,
    double? pendingWithdrawal,
    double? commissionRate,
    double? earningsLastWeek,
    double? earningsLast30Days,
    int? completedTrips,
  }) {
    return DriverWalletModel(
      driverId: driverId ?? this.driverId,
      balance: balance ?? this.balance,
      totalEarned: totalEarned ?? this.totalEarned,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      pendingWithdrawal: pendingWithdrawal ?? this.pendingWithdrawal,
      commissionRate: commissionRate ?? this.commissionRate,
      earningsLastWeek: earningsLastWeek ?? this.earningsLastWeek,
      earningsLast30Days: earningsLast30Days ?? this.earningsLast30Days,
      completedTrips: completedTrips ?? this.completedTrips,
    );
  }

  /// نصيب المنصة من الأرباح الكلية
  double get totalPlatformFees =>
      totalEarned * commissionRate / (1 - commissionRate);

  /// نسبة نصيب السائق
  double get driverSharePercentage => (1 - commissionRate) * 100;
}
