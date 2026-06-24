import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snapix/core/map/factories/app_map_marker_factory.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// Shared helpers for creating map markers.
///
/// Previously duplicated across:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
/// - user/tracking_screen.dart

/// Creates a colored circle marker for map pins (pickup / destination / waypoint).
Future<BitmapDescriptor> createCircleMarker(Color color) async {
  final pictureRecorder = ui.PictureRecorder();
  final canvas = Canvas(pictureRecorder);
  final paint = Paint()..color = color;

  final outerPaint = Paint()..color = color.withOpacity(0.2);
  canvas.drawCircle(const Offset(20, 20), 18, outerPaint);
  canvas.drawCircle(const Offset(20, 20), 10, paint);

  final whitePaint = Paint()..color = AppColors.white;
  canvas.drawCircle(const Offset(20, 20), 5, whitePaint);

  final picture = pictureRecorder.endRecording();
  final image = await picture.toImage(40, 40);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Holds the standard three circle icons: pickup (green), destination (red), waypoint (amber).
class MapCircleIcons {
  BitmapDescriptor? pickupIcon;
  BitmapDescriptor? destIcon;
  BitmapDescriptor? waypointIcon;

  /// Loads all three icons asynchronously.
  Future<void> loadAll() async {
    pickupIcon = await createCircleMarker(AppColors.success);
    destIcon = await createCircleMarker(AppColors.error);
    waypointIcon = await createCircleMarker(AppColors.warning);
  }
}

/// Manages a cache of labeled route-marker icons to avoid recreating them.
///
/// Usage pattern (inside a StatefulWidget):
/// ```dart
/// final _markerCache = RouteMarkerCache();
///
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   _markerCache.onLocaleChanged(Localizations.localeOf(context).languageCode);
/// }
///
/// // inside build:
/// icon: _markerCache.get(
///   cacheKey: 'pickup',
///   label: l.pickupPoint,
///   color: AppColors.success,
///   icon: Icons.trip_origin_rounded,
///   fallback: _circleIcons.pickupIcon,
///   textDirection: Directionality.of(context),
///   onCreated: () { if (mounted) setState(() {}); },
/// ),
/// ```
class RouteMarkerCache {
  final Map<String, BitmapDescriptor> _icons = {};
  final Set<String> _pending = {};
  String? _localeCode;

  /// Call whenever locale changes to invalidate the cache.
  void onLocaleChanged(String localeCode) {
    if (_localeCode != localeCode) {
      _localeCode = localeCode;
      _icons.clear();
      _pending.clear();
    }
  }

  /// Returns a cached [BitmapDescriptor] or triggers async creation and returns [fallback].
  BitmapDescriptor get({
    required String cacheKey,
    required String label,
    required Color color,
    required IconData icon,
    required TextDirection textDirection,
    BitmapDescriptor? fallback,
    VoidCallback? onCreated,
  }) {
    final key = '${_localeCode ?? ''}|$cacheKey|$label';
    final cached = _icons[key];
    if (cached != null) return cached;
    if (!_pending.contains(key)) {
      _pending.add(key);
      AppMapMarkerFactory.labeledPin(
        label: label,
        color: color,
        icon: icon,
        textDirection: textDirection,
      ).then((descriptor) {
        _icons[key] = descriptor;
        _pending.remove(key);
        onCreated?.call();
      });
    }
    return fallback ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  /// Clear the cache entirely.
  void clear() {
    _icons.clear();
    _pending.clear();
  }
}
