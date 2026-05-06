
import 'package:equatable/equatable.dart';

class UserPresenceModel extends Equatable {
  final String userId;
  final double lat;
  final double lng;
  final DateTime lastSeen;

  const UserPresenceModel({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.lastSeen,
  });

  factory UserPresenceModel.fromJson(Map<String, dynamic> json) {
    return UserPresenceModel(
      userId: json['user_id'] as String,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      lastSeen: DateTime.parse(json['last_seen'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'last_seen': lastSeen.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [userId, lat, lng, lastSeen];
}
