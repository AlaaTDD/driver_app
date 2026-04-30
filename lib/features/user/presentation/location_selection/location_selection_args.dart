// lib/features/user/presentation/location_selection/location_selection_args.dart
class LocationSelectionArgs {
  final double? originLat;
  final double? originLng;
  final String? originAddress;

  const LocationSelectionArgs({
    this.originLat,
    this.originLng,
    this.originAddress,
  });
}
