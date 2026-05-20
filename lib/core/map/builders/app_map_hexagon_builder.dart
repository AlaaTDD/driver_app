import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum AppMapHeatLevel { high, medium, low }

/// Builds hexagonal heatmap cells for the driver home map.
/// Replaces the 40+ line `_buildHeatmapHexagons` + `_hexSin`/`_hexCos`
/// helpers duplicated in driver_home_screen.
class AppMapHexagonBuilder {
  AppMapHexagonBuilder._();

  static const double _hexSize = 0.004;
  static const double _hexSin60 = 0.8660254037844387;
  static const double _hexCos60 = 0.5;

  static Color _colorFor(AppMapHeatLevel level) => switch (level) {
        AppMapHeatLevel.high => const Color(0x99FF4060), // error 60%
        AppMapHeatLevel.medium => const Color(0x99F5A524), // warning 60%
        AppMapHeatLevel.low => const Color(0x991FC87A), // success 60%
      };

  static Polygon buildCell({
    required String cellId,
    required double centerLat,
    required double centerLng,
    required AppMapHeatLevel level,
  }) {
    final points = _hexVertices(centerLat, centerLng);
    return Polygon(
      polygonId: PolygonId('hex_$cellId'),
      points: points,
      fillColor: _colorFor(level),
      strokeColor: Colors.transparent,
      strokeWidth: 0,
    );
  }

  static List<LatLng> _hexVertices(double centerLat, double centerLng) {
    const s = _hexSize;
    return [
      LatLng(centerLat + s, centerLng),
      LatLng(centerLat + s * _hexCos60, centerLng + s * _hexSin60),
      LatLng(centerLat - s * _hexCos60, centerLng + s * _hexSin60),
      LatLng(centerLat - s, centerLng),
      LatLng(centerLat - s * _hexCos60, centerLng - s * _hexSin60),
      LatLng(centerLat + s * _hexCos60, centerLng - s * _hexSin60),
    ];
  }
}
