import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snapix/core/constants/map_styles.dart';
import 'package:snapix/core/map/constants/app_map_constants.dart';

/// Unified Google Map widget that auto-applies map style, hides native UI
/// controls, and provides sane defaults. Use this instead of raw [GoogleMap].
class AppGoogleMap extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final void Function(GoogleMapController)? onMapCreated;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Polygon> polygons;
  final Set<Circle> circles;
  final EdgeInsets padding;
  final void Function(LatLng)? onTap;
  final void Function(CameraPosition)? onCameraMove;
  final void Function()? onCameraIdle;
  final void Function()? onCameraMoveStarted;
  final bool myLocationEnabled;
  final AppMapStyle mapStyle;
  final MinMaxZoomPreference minMaxZoomPreference;
  final bool compassEnabled;
  final bool buildingsEnabled;
  final bool indoorViewEnabled;
  final bool fortyFiveDegreeImageryEnabled;

  const AppGoogleMap({
    super.key,
    required this.initialCameraPosition,
    this.onMapCreated,
    this.markers = const {},
    this.polylines = const {},
    this.polygons = const {},
    this.circles = const {},
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.onCameraMove,
    this.onCameraIdle,
    this.onCameraMoveStarted,
    this.myLocationEnabled = false,
    this.mapStyle = AppMapStyle.auto,
    this.minMaxZoomPreference = AppMapZoom.defaultRange,
    this.compassEnabled = false,
    this.buildingsEnabled = true,
    this.indoorViewEnabled = false,
    this.fortyFiveDegreeImageryEnabled = false,
  });

  String? _resolveStyle(BuildContext context) {
    return switch (mapStyle) {
      AppMapStyle.auto => Theme.of(context).brightness == Brightness.dark
          ? kDarkMapStyle
          : kLightMapStyle,
      AppMapStyle.alwaysDark => kDarkMapStyle,
      AppMapStyle.alwaysLight => kLightMapStyle,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: initialCameraPosition,
      onMapCreated: onMapCreated,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: compassEnabled,
      buildingsEnabled: buildingsEnabled,
      indoorViewEnabled: indoorViewEnabled,
      fortyFiveDegreeImageryEnabled: fortyFiveDegreeImageryEnabled,
      markers: markers,
      polylines: polylines,
      polygons: polygons,
      circles: circles,
      padding: padding,
      onTap: onTap,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      onCameraMoveStarted: onCameraMoveStarted,
      minMaxZoomPreference: minMaxZoomPreference,
      style: _resolveStyle(context),
    );
  }
}
