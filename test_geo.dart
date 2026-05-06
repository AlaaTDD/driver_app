import 'package:dart_geohash/dart_geohash.dart';

void main() {
  final hasher = GeoHasher();
  print(hasher.encode(30.0444, 31.2357)); // lat, lng
}
