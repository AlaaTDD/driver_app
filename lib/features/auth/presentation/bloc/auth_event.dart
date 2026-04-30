// lib/features/auth/presentation/bloc/auth_event.dart
import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class SignInRequested extends AuthEvent {
  final String email;
  final String password;

  const SignInRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class SignUpUserRequested extends AuthEvent {
  final String name;
  final String phone;
  final String email;
  final String password;

  const SignUpUserRequested({
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [name, phone, email, password];
}

class SignUpDriverRequested extends AuthEvent {
  final String name;
  final String phone;
  final String email;
  final String password;
  final String nationalId;
  final String nationalIdImageUrl;
  final String licenseNumber;
  final String licenseImageUrl;
  final String criminalRecordUrl;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final int vehicleYear;
  final String vehicleColor;
  final String vehiclePlate;
  final String vehicleImageUrl;

  const SignUpDriverRequested({
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
    required this.nationalId,
    required this.nationalIdImageUrl,
    required this.licenseNumber,
    required this.licenseImageUrl,
    required this.criminalRecordUrl,
    required this.vehicleType,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleColor,
    required this.vehiclePlate,
    required this.vehicleImageUrl,
  });

  @override
  List<Object?> get props => [
        name,
        phone,
        email,
        password,
        nationalId,
        nationalIdImageUrl,
        licenseNumber,
        licenseImageUrl,
        criminalRecordUrl,
        vehicleType,
        vehicleBrand,
        vehicleModel,
        vehicleYear,
        vehicleColor,
        vehiclePlate,
        vehicleImageUrl,
      ];
}

class SignOutRequested extends AuthEvent {}

class UpdateProfileRequested extends AuthEvent {
  final String userId;
  final String? name;
  final String? avatarUrl;

  const UpdateProfileRequested({
    required this.userId,
    this.name,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [userId, name, avatarUrl];
}
