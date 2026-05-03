
import 'package:equatable/equatable.dart';

class RideOfferModel extends Equatable {
  final String id;
  final String passengerName;
  final String pickupAddress;
  final String destinationAddress;
  final double distance;
  final double estimatedPrice;
  final String vehicleType;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final DateTime createdAt;

  const RideOfferModel({
    required this.id,
    required this.passengerName,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.distance,
    required this.estimatedPrice,
    required this.vehicleType,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    required this.createdAt,
  });

  factory RideOfferModel.fromJson(Map<String, dynamic> json) {
    return RideOfferModel(
      id: json['id'] as String? ?? '',
      passengerName: json['passenger_name'] as String? ?? json['user']?['name'] as String? ?? '',
      pickupAddress: json['pickup_address'] as String? ?? '',
      destinationAddress: json['destination_address'] as String? ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble() ?? 0.0,
      vehicleType: json['vehicle_type'] as String? ?? 'standard',
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'passenger_name': passengerName,
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'distance': distance,
      'estimated_price': estimatedPrice,
      'vehicle_type': vehicleType,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static RideOfferModel? fromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    try {
      return RideOfferModel.fromJson(payload);
    } catch (e) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        id,
        passengerName,
        pickupAddress,
        destinationAddress,
        distance,
        estimatedPrice,
        vehicleType,
        pickupLat,
        pickupLng,
        destinationLat,
        destinationLng,
        createdAt,
      ];
}
