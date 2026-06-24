import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../services/location_permission_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

// ── State ──

class LocationPermissionState extends Equatable {
  final LocationStatus status;
  final bool isChecking;

  const LocationPermissionState({
    this.status = LocationStatus.unknown,
    this.isChecking = true,
  });

  LocationPermissionState copyWith({
    LocationStatus? status,
    bool? isChecking,
  }) {
    return LocationPermissionState(
      status: status ?? this.status,
      isChecking: isChecking ?? this.isChecking,
    );
  }

  /// Convenience — is location currently usable?
  bool get isGranted => status == LocationStatus.granted;

  /// Does the user need to go to Settings to fix this?
  bool get needsSettings =>
      status == LocationStatus.permanentlyDenied ||
      status == LocationStatus.restricted;

  /// Is the device-level location toggle off?
  bool get isServiceDisabled => status == LocationStatus.serviceDisabled;

  /// Is something blocking location (anything except granted)?
  bool get isBlocked => !isChecking && status != LocationStatus.granted;

  @override
  List<Object?> get props => [status, isChecking];
}

// ── Cubit ──

/// Reactive cubit that keeps location permission state up-to-date.
///
/// Usage:
/// ```dart
/// // In widget initState or didChangeDependencies:
/// context.read<LocationPermissionCubit>().check();
///
/// // After returning from settings:
/// context.read<LocationPermissionCubit>().recheck();
///
/// // When user taps the CTA:
/// context.read<LocationPermissionCubit>().handleAction();
/// ```
class LocationPermissionCubit extends Cubit<LocationPermissionState> {
  final LocationPermissionService _service;

  LocationPermissionCubit({LocationPermissionService? service})
      : _service = service ?? LocationPermissionService.instance,
        super(const LocationPermissionState());

  /// Initial check — should be called once.
  Future<void> check() async {
    emit(state.copyWith(isChecking: true));
    final status = await _service.checkStatus();
    AppLogger.info('LocationPermissionCubit: status = $status');
    emit(LocationPermissionState(status: status, isChecking: false));
  }

  /// Re-check after returning from Settings (app resumed).
  Future<void> recheck() async {
    final status = await _service.checkStatus();
    AppLogger.info('LocationPermissionCubit: recheck → $status');
    if (status != state.status) {
      emit(LocationPermissionState(status: status, isChecking: false));
    }
  }

  /// Smart action handler:
  /// - If `denied` → try OS dialog first
  /// - If `permanentlyDenied` / `restricted` → open app settings
  /// - If `serviceDisabled` → open location settings
  Future<void> handleAction() async {
    switch (state.status) {
      case LocationStatus.denied:
        // Try the OS dialog
        final newStatus = await _service.requestPermission();
        emit(LocationPermissionState(status: newStatus, isChecking: false));
        break;

      case LocationStatus.permanentlyDenied:
      case LocationStatus.restricted:
        await _service.openAppSettings();
        break;

      case LocationStatus.serviceDisabled:
        await _service.openLocationSettings();
        break;

      default:
        break;
    }
  }
}
