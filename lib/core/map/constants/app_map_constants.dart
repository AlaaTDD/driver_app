import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppMapZoom {
  AppMapZoom._();
  static const double city = 12.0;
  static const double normal = 15.0;
  static const double street = 17.0;
  static const double building = 19.0;

  static const MinMaxZoomPreference trackingRange =
      MinMaxZoomPreference(10, 20);
  static const MinMaxZoomPreference defaultRange =
      MinMaxZoomPreference(5, 20);
}

enum AppMapStyle {
  auto, // follows the current theme (default)
  alwaysDark, // dark map style (tracking, trip_details)
  alwaysLight, // light map style (rare)
}

class AppMapConstants {
  AppMapConstants._();
  static const double defaultSheetPadding = 300.0;
  static const double locationButtonBottomDefault = 120.0;
  static const double defaultCameraAnimDuration = 600; // ms
}
