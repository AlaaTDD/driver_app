import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snapix/core/utils/app_logger.dart';

class MapCameraUtils {
  const MapCameraUtils._();

  static const double defaultPadding = 96;
  static const double defaultMinimumSpan = 0.003;

  static List<LatLng> validPoints(Iterable<LatLng> points) {
    return points
        .where((p) =>
            p.latitude.isFinite &&
            p.longitude.isFinite &&
            p.latitude >= -90 &&
            p.latitude <= 90 &&
            p.longitude >= -180 &&
            p.longitude <= 180 &&
            !(p.latitude == 0.0 && p.longitude == 0.0))
        .toList(growable: false);
  }

  static LatLngBounds? boundsForPoints(
    Iterable<LatLng> points, {
    double minimumLatSpan = defaultMinimumSpan,
    double minimumLngSpan = defaultMinimumSpan,
    double edgeInsetRatio = 0.04,
  }) {
    final valid = validPoints(points);
    if (valid.isEmpty) return null;

    var minLat = valid.first.latitude;
    var maxLat = valid.first.latitude;
    var minLng = valid.first.longitude;
    var maxLng = valid.first.longitude;

    for (final point in valid.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final latSpan = math.max(
      (maxLat - minLat) * (1 + edgeInsetRatio * 2),
      minimumLatSpan,
    );
    final lngSpan = math.max(
      (maxLng - minLng) * (1 + edgeInsetRatio * 2),
      minimumLngSpan,
    );

    return LatLngBounds(
      southwest: LatLng(
        (centerLat - latSpan / 2).clamp(-90.0, 90.0),
        (centerLng - lngSpan / 2).clamp(-180.0, 180.0),
      ),
      northeast: LatLng(
        (centerLat + latSpan / 2).clamp(-90.0, 90.0),
        (centerLng + lngSpan / 2).clamp(-180.0, 180.0),
      ),
    );
  }

  static LatLng centerOf(LatLngBounds bounds) {
    return LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
  }

  static Future<void> fitCameraToPoints(
    GoogleMapController controller,
    Iterable<LatLng> points, {
    double padding = defaultPadding,
    double minimumLatSpan = defaultMinimumSpan,
    double minimumLngSpan = defaultMinimumSpan,
    Duration delay = Duration.zero,
  }) async {
    final bounds = boundsForPoints(
      points,
      minimumLatSpan: minimumLatSpan,
      minimumLngSpan: minimumLngSpan,
    );
    if (bounds == null) return;

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, padding),
      );
    } catch (e, st) {
      AppLogger.warning('MapCameraUtils: bounds animation failed, using center fallback: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(centerOf(bounds), 14),
      );
    }
  }
}
