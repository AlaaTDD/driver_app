import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String? avatarUrl;
  final String role;
  final double rating;
  final int totalTrips;
  final String language;
  final String? fcmToken;
  final bool isActive;
  final bool isAdmin;
  final bool isBlocked;
  final String? blockedReason;
  final DateTime? blockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.avatarUrl,
    required this.role,
    required this.rating,
    required this.totalTrips,
    required this.language,
    this.fcmToken,
    required this.isActive,
    this.isAdmin = false,
    this.isBlocked = false,
    this.blockedReason,
    this.blockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        avatarUrl,
        role,
        rating,
        totalTrips,
        language,
        fcmToken,
        isActive,
        isAdmin,
        isBlocked,
        blockedReason,
        blockedAt,
        createdAt,
        updatedAt,
      ];
}
