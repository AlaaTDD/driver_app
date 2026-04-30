// lib/features/user/presentation/pricing/pricing_args.dart
class PricingArgs {
  final double? originLat;
  final double? originLng;
  final String? originAddress;
  final double? destLat;
  final double? destLng;
  final String? destAddress;

  const PricingArgs({
    this.originLat,
    this.originLng,
    this.originAddress,
    this.destLat,
    this.destLng,
    this.destAddress,
  });
}
