class WaypointArg {
  final double lat;
  final double lng;
  final String address;
  WaypointArg({required this.lat, required this.lng, required this.address});
}

class PricingArgs {
  final double? originLat;
  final double? originLng;
  final String? originAddress;
  final double? destLat;
  final double? destLng;
  final String? destAddress;
  final List<WaypointArg>? waypoints;
  final String? couponCode;
  final double? couponDiscount;

  const PricingArgs({
    this.originLat,
    this.originLng,
    this.originAddress,
    this.destLat,
    this.destLng,
    this.destAddress,
    this.waypoints,
    this.couponCode,
    this.couponDiscount,
  });
}
