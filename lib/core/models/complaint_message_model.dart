import 'package:equatable/equatable.dart';

/// A single message in a complaint conversation thread.
/// Covers: original complaint body, admin replies, and user follow-up replies.
class ComplaintMessageModel extends Equatable {
  final String id;

  /// 'user' | 'admin'
  final String senderType;

  final String message;
  final DateTime? createdAt;

  /// True only for the very first (original) complaint description.
  final bool isOriginal;

  const ComplaintMessageModel({
    required this.id,
    required this.senderType,
    required this.message,
    this.createdAt,
    this.isOriginal = false,
  });

  factory ComplaintMessageModel.fromJson(
    Map<String, dynamic> json, {
    bool isOriginal = false,
  }) {
    return ComplaintMessageModel(
      id: json['id']?.toString() ?? '',
      senderType: json['sender_type'] as String? ?? 'user',
      message: json['message'] as String? ?? '',
      createdAt: _date(json['created_at']),
      isOriginal: json['is_original'] as bool? ?? isOriginal,
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, senderType, message, createdAt, isOriginal];
}
