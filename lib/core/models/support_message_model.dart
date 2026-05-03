
import 'package:equatable/equatable.dart';





class SupportMessageModel extends Equatable {
  final String id;
  final String userId;
  final String message;
  final DateTime createdAt;

  
  final String senderRole;

  
  bool get isFromUser => senderRole == 'user';

  const SupportMessageModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.senderRole = 'user',
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['sender_role'] as String?;
    return SupportMessageModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      senderRole: rawRole ?? 'user',
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'message': message,
      'sender_role': senderRole,
    };
  }

  @override
  List<Object?> get props => [id, userId, message, createdAt, senderRole];
}
