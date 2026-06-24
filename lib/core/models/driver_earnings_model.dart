import 'package:equatable/equatable.dart';

class DriverEarningsModel extends Equatable {
  final double totalEarnings;
  final double availableBalance;
  final double earningsThisWeek;
  final double earningsLast30Days;
  final int completedTrips;
  final double pendingWithdrawal;

  const DriverEarningsModel({
    this.totalEarnings = 0,
    this.availableBalance = 0,
    this.earningsThisWeek = 0,
    this.earningsLast30Days = 0,
    this.completedTrips = 0,
    this.pendingWithdrawal = 0,
  });

  factory DriverEarningsModel.fromJson(Map<String, dynamic> json) {
    return DriverEarningsModel(
      totalEarnings: _asDouble(json['totalEarnings'] ?? json['total_earnings']),
      availableBalance:
          _asDouble(json['availableBalance'] ?? json['available_balance']),
      earningsThisWeek:
          _asDouble(json['earningsThisWeek'] ?? json['earnings_7d']),
      earningsLast30Days: _asDouble(
        json['earningsLast30Days'] ?? json['earnings_30d'],
      ),
      completedTrips: _asInt(json['completedTrips'] ?? json['completed_trips']),
      pendingWithdrawal:
          _asDouble(json['pendingWithdrawal'] ?? json['pending_withdrawal']),
    );
  }

  Map<String, dynamic> toCamelJson() => {
        'totalEarnings': totalEarnings,
        'availableBalance': availableBalance,
        'earningsThisWeek': earningsThisWeek,
        'earningsLast30Days': earningsLast30Days,
        'completedTrips': completedTrips,
        'pendingWithdrawal': pendingWithdrawal,
      };

  Map<String, dynamic> toSnakeJson() => {
        'total_earnings': totalEarnings,
        'available_balance': availableBalance,
        'earnings_7d': earningsThisWeek,
        'earnings_30d': earningsLast30Days,
        'completed_trips': completedTrips,
        'pending_withdrawal': pendingWithdrawal,
      };

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  List<Object?> get props => [
        totalEarnings,
        availableBalance,
        earningsThisWeek,
        earningsLast30Days,
        completedTrips,
        pendingWithdrawal,
      ];
}
