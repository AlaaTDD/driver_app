import 'package:dart_geohash/dart_geohash.dart';

class GeohashHelper {
  static final _geoHasher = GeoHasher();

  static String encode(double lat, double lng, {int precision = 6}) {
    return _geoHasher.encode(lng, lat).substring(0, precision);
  }

  static List<String> getNeighborCells(String geohash) {
    final neighborMap = _geoHasher.neighbors(geohash);
    return neighborMap.values.whereType<String>().toList();
  }

  static List<String> getCellAndNeighbors(double lat, double lng,
      {int precision = 6}) {
    final center = encode(lat, lng, precision: precision);
    return [center, ...getNeighborCells(center)];
  }

  static bool hasCellChanged(
    String currentGeohash,
    String previousGeohash,
  ) {
    return currentGeohash != previousGeohash;
  }

  static ({double lat, double lng}) decode(String geohash) {
    final decoded = _geoHasher.decode(geohash);
    return (lat: decoded[1], lng: decoded[0]);
  }
}
