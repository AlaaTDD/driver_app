class LocationSelectionArgs {
  final double? originLat;
  final double? originLng;
  final String? originAddress;
  final String? initialCouponCode; // Pre-applied coupon from home screen
  final double? initialCouponDiscount; // Validated discount amount

  const LocationSelectionArgs({
    this.originLat,
    this.originLng,
    this.originAddress,
    this.initialCouponCode,
    this.initialCouponDiscount,
  });
}
