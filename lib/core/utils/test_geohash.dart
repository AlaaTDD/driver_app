import 'dart:developer' as developer;
import 'package:dart_geohash/dart_geohash.dart';
import '../constants/app_constants.dart';

void main() {
  final geoHasher = GeoHasher();
  final lat = AppConstants.defaultMapCenter.latitude;
  final lng = AppConstants.defaultMapCenter.longitude;
  developer.log('lat, lng: ${geoHasher.encode(lat, lng)}');
  developer.log('lng, lat: ${geoHasher.encode(lng, lat)}');
}
