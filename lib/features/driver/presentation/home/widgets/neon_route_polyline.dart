import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NeonRoutePolyline {
  const NeonRoutePolyline._();

  static double drawProgress(double loopValue, {double drawWindow = 0.86}) {
    if (loopValue <= 0 || loopValue >= drawWindow) {
      return loopValue >= drawWindow ? 1.0 : 0.0;
    }
    final t = (loopValue / drawWindow).clamp(0.0, 1.0);
    return 1 - math.pow(1 - t, 3).toDouble();
  }

  static double fadeOpacity(
    double loopValue, {
    double fadeStart = 0.86,
    double fadeEnd = 0.98,
  }) {
    if (loopValue < fadeStart) return 1.0;
    if (loopValue >= fadeEnd) return 0.0;
    final t = ((loopValue - fadeStart) / (fadeEnd - fadeStart)).clamp(
      0.0,
      1.0,
    );
    return 1 - t;
  }

  static Set<Polyline> build({
    required List<LatLng> points,
    required double progress,
    required Color color,
    String idPrefix = 'neon_route',
    int coreWidth = 5,
    int glowWidth = 13,
    int haloWidth = 22,
    double opacity = 1.0,
  }) {
    final visiblePoints = pointsForProgress(points, progress);
    if (visiblePoints.length < 2 || opacity <= 0) return const {};

    final alpha = opacity.clamp(0.0, 1.0);
    return {
      Polyline(
        polylineId: PolylineId('${idPrefix}_halo'),
        points: visiblePoints,
        color: color.withValues(alpha: 0.12 * alpha),
        width: haloWidth,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ),
      Polyline(
        polylineId: PolylineId('${idPrefix}_glow'),
        points: visiblePoints,
        color: color.withValues(alpha: 0.34 * alpha),
        width: glowWidth,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 2,
      ),
      Polyline(
        polylineId: PolylineId('${idPrefix}_core'),
        points: visiblePoints,
        color: color.withValues(alpha: 0.96 * alpha),
        width: coreWidth,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 3,
      ),
    };
  }

  static List<LatLng> pointsForProgress(List<LatLng> points, double progress) {
    final valid = points
        .where((p) =>
            p.latitude.isFinite &&
            p.longitude.isFinite &&
            !(p.latitude == 0 && p.longitude == 0))
        .toList(growable: false);
    if (valid.length < 2) return valid;

    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) return const [];
    if (clampedProgress >= 1) return valid;

    final segmentLengths = <double>[];
    var totalLength = 0.0;
    for (var i = 0; i < valid.length - 1; i++) {
      final length = _distanceMeters(valid[i], valid[i + 1]);
      segmentLengths.add(length);
      totalLength += length;
    }
    if (totalLength <= 0) return valid.take(2).toList(growable: false);

    final targetLength = totalLength * clampedProgress;
    final visible = <LatLng>[valid.first];
    var travelled = 0.0;

    for (var i = 0; i < segmentLengths.length; i++) {
      final segmentLength = segmentLengths[i];
      final nextTravelled = travelled + segmentLength;

      if (targetLength >= nextTravelled) {
        visible.add(valid[i + 1]);
        travelled = nextTravelled;
        continue;
      }

      final segmentProgress =
          segmentLength == 0 ? 1.0 : (targetLength - travelled) / segmentLength;
      visible.add(_lerp(valid[i], valid[i + 1], segmentProgress));
      break;
    }

    return visible;
  }

  static LatLng _lerp(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _degToRad(double degrees) => degrees * math.pi / 180;
}
