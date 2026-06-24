import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends Equatable {
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

  const UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'user',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: json['total_trips'] as int? ?? 0,
      language: json['language'] as String? ?? 'ar',
      fcmToken: json['fcm_token'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isAdmin: json['is_admin'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ?? false,
      blockedReason: json['blocked_reason'] as String?,
      blockedAt: json['blocked_at'] != null
          ? DateTime.tryParse(json['blocked_at'] as String? ?? '')
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'role': role,
      'rating': rating,
      'total_trips': totalTrips,
      'language': language,
      'fcm_token': fcmToken,
      'is_active': isActive,
      'is_admin': isAdmin,
      'is_blocked': isBlocked,
      'blocked_reason': blockedReason,
      'blocked_at': blockedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      name: name,
      phone: phone,
      email: email,
      avatarUrl: avatarUrl,
      role: role,
      rating: rating,
      totalTrips: totalTrips,
      language: language,
      fcmToken: fcmToken,
      isActive: isActive,
      isAdmin: isAdmin,
      isBlocked: isBlocked,
      blockedReason: blockedReason,
      blockedAt: blockedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    String? role,
    double? rating,
    int? totalTrips,
    String? language,
    String? fcmToken,
    bool? isActive,
    bool? isAdmin,
    bool? isBlocked,
    String? blockedReason,
    DateTime? blockedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      language: language ?? this.language,
      fcmToken: fcmToken ?? this.fcmToken,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedReason: blockedReason ?? this.blockedReason,
      blockedAt: blockedAt ?? this.blockedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
