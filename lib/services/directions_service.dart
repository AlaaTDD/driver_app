import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class DirectionsResult {
  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  const DirectionsResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000.0;
}

class DirectionsService {
  static const _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  
  
  
  static final Map<String, _CachedResult> _cache = {};
  static const _cacheTtl = Duration(minutes: 5);
  static const int _maxCacheSize = 50;

  static String _cacheKey(double oLat, double oLng, double dLat, double dLng) {
    return '${oLat.toStringAsFixed(4)},${oLng.toStringAsFixed(4)}'
        '→${dLat.toStringAsFixed(4)},${dLng.toStringAsFixed(4)}';
  }

  static Future<DirectionsResult?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String apiKey,
  }) async {
    
    final key = _cacheKey(originLat, originLng, destLat, destLng);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      debugPrint('📍 DirectionsService: Cache HIT for $key');
      return cached.result;
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl'
        '?origin=$originLat,$originLng'
        '&destination=$destLat,$destLng'
        '&alternatives=false'
        '&key=$apiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final route = (data['routes'] as List).first as Map<String, dynamic>;
      final leg = (route['legs'] as List).first as Map<String, dynamic>;
      final encodedPolyline = route['overview_polyline']['points'] as String;
      final distanceMeters = (leg['distance']['value'] as int);
      final durationSeconds = (leg['duration']['value'] as int);
      final result = DirectionsResult(
        points: _decodePolyline(encodedPolyline),
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      );

      
      if (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = _CachedResult(result: result, timestamp: DateTime.now());

      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ DirectionsService: Route fetch failed: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  
  static void clearCache() => _cache.clear();

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}


class _CachedResult {
  final DirectionsResult result;
  final DateTime timestamp;
  const _CachedResult({required this.result, required this.timestamp});
}
