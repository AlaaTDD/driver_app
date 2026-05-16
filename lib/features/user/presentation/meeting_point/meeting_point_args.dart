
class MeetingPointArgs {
  final double? originLat;
  final double? originLng;
  final String? originAddress;
  final double? destLat;
  final double? destLng;
  final String? destAddress;
  final double? distanceKm;
  final double? price;
  final String? vehicleType;
  final String? paymentMethod;
  final String? couponCode;
  final List<dynamic>? waypoints; // Using dynamic or WaypointArg (need to import it)

  const MeetingPointArgs({
    this.originLat,
    this.originLng,
    this.originAddress,
    this.destLat,
    this.destLng,
    this.destAddress,
    this.distanceKm,
    this.price,
    this.vehicleType,
    this.paymentMethod,
    this.couponCode,
    this.waypoints,
  });
}
