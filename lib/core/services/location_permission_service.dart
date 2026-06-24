import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';

/// Unified location status covering both permission and service state.
enum LocationStatus {
  /// Permission granted and service enabled — ready to use.
  granted,

  /// First-time or soft deny — can still request via system dialog.
  denied,

  /// User chose "Don't Allow" / "Never" — must open app settings.
  permanentlyDenied,

  /// iOS-only: restricted by parental controls / MDM.
  restricted,

  /// Device-level location service is turned off.
  serviceDisabled,

  /// Unknown / initial state.
  unknown,
}

/// Centralized service for checking & requesting location permission
/// and navigating to the correct settings page on iOS / Android.
class LocationPermissionService {
  LocationPermissionService._();
  static final instance = LocationPermissionService._();

  final GeolocatorPlatform _geo = GeolocatorPlatform.instance;

  /// Returns the current unified [LocationStatus].
  Future<LocationStatus> checkStatus() async {
    // 1) Check if the device-level location service is on
    final serviceEnabled = await _geo.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    // 2) Check the app-level permission
    final perm = await _geo.checkPermission();
    return _mapPermission(perm);
  }

  /// Request permission via the OS dialog.
  /// Returns the resulting [LocationStatus].
  Future<LocationStatus> requestPermission() async {
    final serviceEnabled = await _geo.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    final perm = await _geo.requestPermission();
    return _mapPermission(perm);
  }

  /// Opens the **app-level** settings page.
  /// On iOS this opens Settings → YourApp.
  /// On Android this opens App Info (where the user can toggle permissions).
  Future<bool> openAppSettings() async {
    return await GeolocatorPlatform.instance.openAppSettings();
  }

  /// Opens the **device-level** location settings.
  /// iOS: Settings → Privacy → Location Services.
  /// Android: Settings → Location.
  Future<bool> openLocationSettings() async {
    return await GeolocatorPlatform.instance.openLocationSettings();
  }

  /// Whether the current status means location is usable.
  bool isGranted(LocationStatus status) => status == LocationStatus.granted;

  /// Whether the user needs to go to settings (can't use system dialog).
  bool needsSettings(LocationStatus status) =>
      status == LocationStatus.permanentlyDenied ||
      status == LocationStatus.restricted;

  /// Whether the device-level location toggle is off.
  bool isServiceDisabled(LocationStatus status) =>
      status == LocationStatus.serviceDisabled;

  // ── Private ──

  LocationStatus _mapPermission(LocationPermission perm) {
    switch (perm) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationStatus.granted;
      case LocationPermission.denied:
        return LocationStatus.denied;
      case LocationPermission.deniedForever:
        return LocationStatus.permanentlyDenied;
      case LocationPermission.unableToDetermine:
        // iOS "restricted" maps to this in some geolocator versions
        if (Platform.isIOS) return LocationStatus.restricted;
        return LocationStatus.denied;
    }
  }
}
