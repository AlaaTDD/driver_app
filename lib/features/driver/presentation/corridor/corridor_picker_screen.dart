import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snapix/core/constants/env_constants.dart';
import 'package:snapix/core/map/app_map.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/utils/app_toast.dart';
import 'package:snapix/core/utils/map_camera_utils.dart';
import 'package:snapix/core/widgets/app_button.dart';
import 'package:snapix/features/driver/data/repositories/corridor_repository.dart';
import 'package:snapix/services/directions_service.dart';
import 'package:snapix/services/supabase_service.dart';
import '../home/widgets/neon_route_polyline.dart';
import 'widgets/corridor_hint_pill.dart';
import 'widgets/point_chip.dart';
import 'widgets/corridor_panel_action.dart';
import 'widgets/radius_slider.dart';

/// Arguments needed to push the [CorridorPickerScreen].
class CorridorPickerArgs {
  final LatLng initialCenter;
  const CorridorPickerArgs({required this.initialCenter});
}

/// Full-screen corridor picker extracted from `driver_home_screen.dart`.
/// Allows drivers to set a preferred corridor (origin → destination) with
/// adjustable radius zones.
class CorridorPickerScreen extends StatefulWidget {
  final LatLng initialCenter;
  const CorridorPickerScreen({super.key, required this.initialCenter});

  @override
  State<CorridorPickerScreen> createState() => _CorridorPickerScreenState();
}

enum _CorridorPointTarget { origin, destination }

class _CorridorPickerScreenState extends State<CorridorPickerScreen>
    with SingleTickerProviderStateMixin {
  static const _neonLoopDuration = Duration(milliseconds: 3200);
  static const _neonFrameInterval = Duration(milliseconds: 33);
  static const _neonCoreWidth = 5;
  static const _neonGlowWidth = 13;
  static const _neonHaloWidth = 22;

  // Tap step: 0 = waiting for origin, 1 = waiting for dest, 2 = done
  int _step = 0;

  GoogleMapController? _mapCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final CorridorRepository _repo = CorridorRepository();

  LatLng? _originPt;
  LatLng? _destPt;
  String? _originAddr;
  String? _destAddr;
  _CorridorPointTarget _pickTarget = _CorridorPointTarget.origin;
  double _originRadiusKm = 2.0;
  double _destRadiusKm = 3.0;
  bool _isResolving = false;
  bool _isSaving = false;

  List<LatLng> _routePoints = [];
  late final AnimationController _neonRouteCtrl;
  Duration _lastNeonFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _neonRouteCtrl = AnimationController(
      vsync: this,
      duration: _neonLoopDuration,
    )..addListener(_onNeonRouteFrame);
    _loadExistingCorridor();
  }

  @override
  void dispose() {
    _neonRouteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onNeonRouteFrame() {
    if (_routePoints.length < 2) return;
    final elapsed = _neonRouteCtrl.lastElapsedDuration ?? Duration.zero;
    if (elapsed - _lastNeonFrame < _neonFrameInterval) return;
    _lastNeonFrame = elapsed;
    if (mounted) setState(() {});
  }

  void _restartNeonRouteLoop() {
    if (_routePoints.length < 2) {
      _stopNeonRouteLoop();
      return;
    }
    _lastNeonFrame = Duration.zero;
    _neonRouteCtrl
      ..stop()
      ..reset()
      ..repeat();
  }

  void _stopNeonRouteLoop() {
    _neonRouteCtrl
      ..stop()
      ..reset();
    _lastNeonFrame = Duration.zero;
  }

  void _clearRoutePreview() {
    _stopNeonRouteLoop();
    _routePoints = [];
  }

  Future<void> _loadExistingCorridor() async {
    setState(() => _isResolving = true);
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid != null) {
        final data = await _repo.loadCorridor(uid);
        if (data != null && data.isComplete) {
          _originPt = LatLng(data.originLat!, data.originLng!);
          _destPt = LatLng(data.destLat!, data.destLng!);
          _originRadiusKm = data.originRadiusKm ?? 2.0;
          _destRadiusKm = data.destRadiusKm ?? 3.0;
          _step = 2;
          _pickTarget = _CorridorPointTarget.origin;

          // Try reverse geocoding
          try {
            final oMarks = await placemarkFromCoordinates(
                data.originLat!, data.originLng!);
            if (oMarks.isNotEmpty) {
              _originAddr =
                  '${oMarks.first.street ?? ''}, ${oMarks.first.locality ?? ''}';
            }
            final dMarks = await placemarkFromCoordinates(
                data.destLat!, data.destLng!);
            if (dMarks.isNotEmpty) {
              _destAddr =
                  '${dMarks.first.street ?? ''}, ${dMarks.first.locality ?? ''}';
            }
          } catch (e) {
            debugPrint('⚠️ CorridorPicker: reverse geocode failed: $e');
          }

          _fetchAndDrawRoute();
        }
      }
    } catch (e) {
      debugPrint('Error loading corridor: $e');
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isResolving = true);
    try {
      final locs = await locationFromAddress(query);
      if (locs.isNotEmpty) {
        final ll = LatLng(locs.first.latitude, locs.first.longitude);
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 14));
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        AppToast.error(l.errorLocationNotFound);
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _onMapTap(LatLng ll) async {
    if (_isSaving) return;
    final target = _pickTarget;
    setState(() => _isResolving = true);

    String? address;
    try {
      final placemarks =
          await placemarkFromCoordinates(ll.latitude, ll.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = '${p.street ?? ''}, ${p.locality ?? ''}';
      }
    } catch (e) {
      address =
          '${ll.latitude.toStringAsFixed(4)}, ${ll.longitude.toStringAsFixed(4)}';
    }

    var shouldFetchRoute = false;
    setState(() {
      _clearRoutePreview();
      if (target == _CorridorPointTarget.origin) {
        _originPt = ll;
        _originAddr = address;
        if (_destPt != null) {
          _step = 2;
          shouldFetchRoute = true;
        } else {
          _step = 1;
          _pickTarget = _CorridorPointTarget.destination;
        }
      } else {
        _destPt = ll;
        _destAddr = address;
        if (_originPt != null) {
          _step = 2;
          shouldFetchRoute = true;
        } else {
          _step = 0;
          _pickTarget = _CorridorPointTarget.origin;
        }
      }
      _isResolving = false;
    });
    if (shouldFetchRoute) await _fetchAndDrawRoute();
  }

  Future<void> _fetchAndDrawRoute() async {
    if (_originPt == null || _destPt == null) return;
    final result = await DirectionsService.getRoute(
      originLat: _originPt!.latitude,
      originLng: _originPt!.longitude,
      destLat: _destPt!.latitude,
      destLng: _destPt!.longitude,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted || result == null) return;
    setState(() {
      _routePoints = result.points;
    });
    _restartNeonRouteLoop();

    final ctrl = _mapCtrl;
    if (ctrl != null) {
      await MapCameraUtils.fitCameraToPoints(
        ctrl,
        _routePoints,
        padding: 92,
        delay: const Duration(milliseconds: 120),
      );
    }
  }

  void _reset() {
    _stopNeonRouteLoop();
    setState(() {
      _step = 0;
      _pickTarget = _CorridorPointTarget.origin;
      _originPt = null;
      _destPt = null;
      _originAddr = null;
      _destAddr = null;
      _routePoints = [];
    });
  }

  void _onOriginChipTap() {
    setState(() {
      if (_originPt != null) {
        _originPt = null;
        _originAddr = null;
        _clearRoutePreview();
      }
      _pickTarget = _CorridorPointTarget.origin;
      _step = _originPt != null && _destPt != null
          ? 2
          : _originPt != null
              ? 1
              : 0;
    });
  }

  void _onDestinationChipTap() {
    setState(() {
      if (_destPt != null) {
        _destPt = null;
        _destAddr = null;
        _clearRoutePreview();
      }
      _pickTarget = _CorridorPointTarget.destination;
      _step = _originPt != null && _destPt != null ? 2 : 1;
    });
  }

  Future<void> _save() async {
    if (_originPt == null || _destPt == null) return;
    setState(() => _isSaving = true);
    try {
      final uid = SupabaseService.currentUser!.id;
      await _repo.saveCorridor(
        uid,
        CorridorData(
          originLat: _originPt!.latitude,
          originLng: _originPt!.longitude,
          destLat: _destPt!.latitude,
          destLng: _destPt!.longitude,
          originRadiusKm: _originRadiusKm,
          destRadiusKm: _destRadiusKm,
        ),
      );
      if (mounted) {
        Navigator.pop<Map<String, LatLng>>(context, {
          'origin': _originPt!,
          'dest': _destPt!,
        });
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        AppToast.error(l.errorWithDetails(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clear() async {
    try {
      _stopNeonRouteLoop();
      final uid = SupabaseService.currentUser!.id;
      await _repo.clearCorridor(uid);
      if (mounted) {
        Navigator.pop<Map<String, LatLng>>(context, {'cleared': LatLng(0, 0)});
      }
    } catch (e) {
      debugPrint('CorridorPicker: clear failed $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = context.bgColor;
    final neonRouteColor =
        isDark ? const Color(0xFF34E7FF) : const Color(0xFF4169FF);
    final neonRouteProgress = NeonRoutePolyline.drawProgress(
      _neonRouteCtrl.value,
    );
    final neonRouteOpacity = NeonRoutePolyline.fadeOpacity(
      _neonRouteCtrl.value,
    );

    final hasBothPoints = _originPt != null && _destPt != null;
    final String hintText = hasBothPoints
        ? l.corridorReviewHint
        : _pickTarget == _CorridorPointTarget.destination
            ? l.corridorPickDestinationHint
            : l.corridorPickOriginHint;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: panelColor.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.26),
                    blurRadius: 8)
              ],
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 17,
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.7)
                    : AppColors.black.withValues(alpha: 0.87)),
          ),
        ),
      ),
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────
        AppGoogleMap(
          initialCameraPosition:
              CameraPosition(target: widget.initialCenter, zoom: 13),
          onMapCreated: (ctrl) => _mapCtrl = ctrl,
          onTap: _onMapTap,
          myLocationEnabled: true,
          circles: {
            if (_originPt != null)
              Circle(
                circleId: const CircleId('origin_zone'),
                center: _originPt!,
                radius: _originRadiusKm * 1000,
                fillColor: AppColors.success.withValues(alpha: 0.12),
                strokeColor: AppColors.success.withValues(alpha: 0.8),
                strokeWidth: 2,
              ),
            if (_destPt != null)
              Circle(
                circleId: const CircleId('dest_zone'),
                center: _destPt!,
                radius: _destRadiusKm * 1000,
                fillColor: AppColors.primary.withValues(alpha: 0.12),
                strokeColor: AppColors.primary.withValues(alpha: 0.8),
                strokeWidth: 2,
              ),
          },
          polylines: _routePoints.isNotEmpty
              ? NeonRoutePolyline.build(
                  points: _routePoints,
                  progress: neonRouteProgress,
                  opacity: neonRouteOpacity,
                  color: neonRouteColor,
                  idPrefix: 'corridor_neon',
                  coreWidth: _neonCoreWidth,
                  glowWidth: _neonGlowWidth,
                  haloWidth: _neonHaloWidth,
                )
              : (_originPt != null && _destPt != null)
                  ? {
                      Polyline(
                        polylineId: const PolylineId('corridor_straight'),
                        points: [_originPt!, _destPt!],
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 3,
                        patterns: [
                          PatternItem.dash(20),
                          PatternItem.gap(10)
                        ],
                      ),
                    }
                  : {},
          markers: {
            if (_originPt != null)
              Marker(
                markerId: const MarkerId('origin'),
                position: _originPt!,
                anchor: const Offset(0.5, 0.5),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                infoWindow:
                    InfoWindow(title: l.corridorStart, snippet: _originAddr),
              ),
            if (_destPt != null)
              Marker(
                markerId: const MarkerId('dest'),
                position: _destPt!,
                anchor: const Offset(0.5, 0.5),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
                infoWindow:
                    InfoWindow(title: l.corridorEnd, snippet: _destAddr),
              ),
          },
        ),

        // ── Search Bar ──────────────────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: panelColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.26),
                    blurRadius: 10)
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.search_rounded,
                  color: AppColors.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l.corridorSearchHint,
                    hintStyle:
                        const TextStyle(fontSize: 13, color: AppColors.grey),
                    border: InputBorder.none,
                  ),
                  style:
                      TextStyle(fontSize: 13, color: context.textPrimary),
                  onSubmitted: _searchLocation,
                ),
              ),
              if (_isResolving)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ),
        ),

        // ── Step hint banner ────────────────────────────────────────────
        if (!_isResolving)
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 8,
            start: 66,
            end: 16,
            child: CorridorHintPill(hint: hintText),
          ),

        if (_isResolving)
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 8,
            start: 66,
            end: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: AppColors.white, strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(l.processing,
                    style: const TextStyle(
                        color: AppColors.white, fontSize: 13)),
              ]),
            ),
          ),

        // ── Bottom panel ────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.38),
                    blurRadius: 20,
                    offset: const Offset(0, -4))
              ],
            ),
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(100)))),
                  const SizedBox(height: 14),

                  // Origin + Dest chips
                  Row(children: [
                    PointChip(
                      isDone: _originPt != null,
                      isActive:
                          _pickTarget == _CorridorPointTarget.origin &&
                              _originPt == null,
                      color: AppColors.success,
                      icon: Icons.trip_origin_rounded,
                      label: l.pickupPoint,
                      address: _originAddr,
                      onTap: _onOriginChipTap,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppColors.grey),
                    ),
                    PointChip(
                      isDone: _destPt != null,
                      isActive:
                          _pickTarget == _CorridorPointTarget.destination &&
                              _destPt == null,
                      color: AppColors.primary,
                      icon: Icons.flag_rounded,
                      label: l.corridorEnd,
                      address: _destAddr,
                      onTap: _onDestinationChipTap,
                    ),
                  ]),

                  // Sliders — only visible when both points are set
                  if (_step == 2) ...[
                    const SizedBox(height: 16),
                    RadiusSlider(
                      label: l.corridorOriginRadius,
                      color: AppColors.success,
                      value: _originRadiusKm,
                      min: 0.5,
                      max: 10.0,
                      onChanged: (v) =>
                          setState(() => _originRadiusKm = v),
                    ),
                    const SizedBox(height: 8),
                    RadiusSlider(
                      label: l.corridorDestinationRadius,
                      color: AppColors.primary,
                      value: _destRadiusKm,
                      min: 0.5,
                      max: 15.0,
                      onChanged: (v) =>
                          setState(() => _destRadiusKm = v),
                    ),
                  ],

                  const SizedBox(height: 16),

                  AppButton(
                    text: _step == 0
                        ? l.selectOriginFirst
                        : _step == 1
                            ? l.selectDestination
                            : l.savePreferredCorridor,
                    isLoading: _isSaving,
                    leadingIcon: Icons.save_rounded,
                    onPressed: (_step == 2 && !_isSaving && !_isResolving)
                        ? _save
                        : null,
                  ),

                  if (_originPt != null || _destPt != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CorridorPanelAction(
                            label: l.resetButton,
                            icon: Icons.refresh_rounded,
                            color: AppColors.warning,
                            onTap: _reset,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CorridorPanelAction(
                            label: l.clearButton,
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.error,
                            onTap: _clear,
                          ),
                        ),
                      ],
                    ),
                  ],
                ]),
          ),
        ),
      ]),
    );
  }
}
