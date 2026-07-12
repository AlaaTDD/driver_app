import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserEntity user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

/// حالة "Requires Action" — السائق يحتاج تعديل حقل أو أكثر ثم إعادة الإرسال.
/// يقابل drivers_profile.account_status == 'pending_review'.
class AuthDriverPending extends AuthState {
  final UserEntity user;
  final String? revisionReason;

  const AuthDriverPending(this.user, {this.revisionReason});

  @override
  List<Object?> get props => [user, revisionReason];
}

/// حالة "Under Review" — السائق أرسل تعديلاته وينتظر مراجعة الأدمن.
/// حالة قراءة فقط: لا يجوز عرض أي زر تعديل أثناءها. يقابل
/// drivers_profile.account_status == 'under_review'. مصدر التمييز بينها
/// وبين AuthDriverPending هو account_status من الـ DB حصراً — وليس أي فحص
/// على field_statuses أو driver_revision_requests.status على مستوى العميل.
/// انظر MASTER_PLAN.md القسم 3.1 و4.4.
class AuthDriverUnderReview extends AuthState {
  final UserEntity user;

  const AuthDriverUnderReview(this.user);

  @override
  List<Object?> get props => [user];
}

/// حالة توجيه صريحة للسائق المحظور أثناء الجلسة المفتوحة أو عند تسجيل الدخول؛
/// تحل محل الاعتماد السابق على تسجيل خروج صامت + AuthError('errorUserBlocked')،
/// لأنها كانت غير قادرة على منع التوجيه لشاشة داخلية أثناء جلسة مفتوحة فعلاً.
/// انظر MASTER_PLAN.md القسم 4، المرحلة ج، البند 9.
class AuthDriverBlocked extends AuthState {
  final UserEntity user;
  final String? reason;

  const AuthDriverBlocked(this.user, {this.reason});

  @override
  List<Object?> get props => [user, reason];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
