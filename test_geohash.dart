import 'package:dart_geohash/dart_geohash.dart';

void main() {
  final hasher = GeoHasher();
  final n = hasher.neighbors('stq4yv');
  print(n);
}
