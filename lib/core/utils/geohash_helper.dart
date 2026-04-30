// lib/core/utils/geohash_helper.dart
import 'package:dart_geohash/dart_geohash.dart';

/// Geohash utility class — the foundation of the cell system.
///
/// **Cell System Usage:**
/// - precision 6 → ~1.2km cells → used for driver presence tracking (user home)
/// - precision 5 → ~5km cells   → used for trip search broadcast & heatmap
///
/// **This is NOT the heatmap.** The cell system handles presence and proximity.
/// The heatmap is a separate visualization layer built on top of trip history data.
class GeohashHelper {
  static final _geoHasher = GeoHasher();

  /// Encode a lat/lng into a geohash string
  // FIX M14: dart_geohash expects (longitude, latitude) natively.
  static String encode(double lat, double lng, {int precision = 6}) {
    return _geoHasher.encode(lng, lat).substring(0, precision);
  }

  /// Get the 8 neighboring cells of a geohash
  /// Uses the library's accurate neighbor calculation instead of offset approximation
  static List<String> getNeighborCells(String geohash) {
    // Use the library's neighbor calculation which handles geohash boundaries correctly
    final neighborMap = _geoHasher.neighbors(geohash);
    return [
      if (neighborMap.containsKey('n')) neighborMap['n']!,
      if (neighborMap.containsKey('ne')) neighborMap['ne']!,
      if (neighborMap.containsKey('e')) neighborMap['e']!,
      if (neighborMap.containsKey('se')) neighborMap['se']!,
      if (neighborMap.containsKey('s')) neighborMap['s']!,
      if (neighborMap.containsKey('sw')) neighborMap['sw']!,
      if (neighborMap.containsKey('w')) neighborMap['w']!,
      if (neighborMap.containsKey('nw')) neighborMap['nw']!,
    ];
  }

  /// Get the center cell + all 8 neighbors (9 cells total)
  static List<String> getCellAndNeighbors(
      double lat, double lng, {int precision = 6}) {
    final center = encode(lat, lng, precision: precision);
    return [center, ...getNeighborCells(center)];
  }

  /// Check if the geohash cell has changed between two positions
  static bool hasCellChanged(
    String currentGeohash,
    String previousGeohash,
  ) {
    return currentGeohash != previousGeohash;
  }

  /// Decode a geohash to its center lat/lng
  static ({double lat, double lng}) decode(String geohash) {
    final decoded = _geoHasher.decode(geohash);
    return (lat: decoded[1], lng: decoded[0]);
  }
}
