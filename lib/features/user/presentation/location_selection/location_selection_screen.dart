
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/constants/env_constants.dart';
import '../../../../services/directions_service.dart';
import 'bloc/location_bloc.dart';
import 'bloc/location_event.dart';
import 'bloc/location_state.dart';
import 'location_selection_args.dart';
import '../pricing/pricing_args.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/localization/generated/app_localizations.dart';



enum _PickMode { none, origin, destination, waypoint }

class _Suggestion {
  final String label;
  final String detail;
  final double lat, lng;
  const _Suggestion({required this.label, required this.detail, required this.lat, required this.lng});
}

class _WaypointModel {
  final TextEditingController ctrl = TextEditingController();
  final FocusNode focus = FocusNode();
  double? lat;
  double? lng;
  String? address;

  void dispose() {
    ctrl.dispose();
    focus.dispose();
  }
}



const String kDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0B1120"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6B8DB0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#060C18"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1A2E4A"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0D1E35"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#1E3A60"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#253E5C"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#182C44"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#7490B0"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#051020"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3A5A7A"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1A2E4A"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#0D1A2A"}]}
]
''';

const String kLightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#EEF2F7"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#4A6080"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#DCE6F0"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#F5F8FC"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#E4EDF8"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#C8D8E8"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#7A8FA8"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#B4D0E8"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#6A8FAA"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#C4D4E4"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#E0EAF2"}]}
]
''';

class LocationSelectionScreen extends StatefulWidget {
  final LocationSelectionArgs? extra;

  const LocationSelectionScreen({super.key, this.extra});

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen>
    with TickerProviderStateMixin {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _originFocus = FocusNode();
  final _destFocus = FocusNode();
  final _mapCtrl = Completer<GoogleMapController>();

  double? _originLat, _originLng;
  String? _originAddress;
  double? _destLat, _destLng;
  String? _destAddress;

  final List<_WaypointModel> _waypoints = [];
  int _pickWaypointIdx = -1; // which waypoint is being picked

  String _activeFieldId = 'none'; // 'origin', 'destination', 'waypoint_X'
  _PickMode _pickMode = _PickMode.none;
  LatLng _mapCenter = AppConstants.defaultMapCenter;
  bool _isPickConfirming = false;
  String _livePickAddress = '';
  bool _isReversing = false;
  Timer? _reverseDebounce;

  List<_Suggestion> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

  List<LatLng> _routePoints = [];
  List<LatLng> _visiblePoints = [];
  AnimationController? _drawCtrl;

  
  AnimationController? _cardPulseCtrl;
  Animation<double>? _cardPulseAnim;

  static const _defaultCamera = CameraPosition(target: AppConstants.defaultMapCenter, zoom: 14);

  @override
  void initState() {
    super.initState();

    _cardPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _cardPulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardPulseCtrl!, curve: Curves.easeInOut),
    );
    _drawCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..addListener(_onDrawFrame);
    if (widget.extra?.originLat != null) {
      _originLat = widget.extra!.originLat;
      _originLng = widget.extra!.originLng;
      _originAddress = widget.extra!.originAddress;
      _originCtrl.text = _originAddress ?? '';
    } else {
      context.read<LocationBloc>().add(const SelectCurrentLocation());
    }
    _originFocus.addListener(() => _onFocusChanged('origin', _originFocus));
    _destFocus.addListener(() => _onFocusChanged('destination', _destFocus));
    _originCtrl.addListener(() => _onTextChanged(_originCtrl.text, 'origin'));
    _destCtrl.addListener(() => _onTextChanged(_destCtrl.text, 'destination'));
  }

  void _onFocusChanged(String id, FocusNode node) {
    setState(() {
      if (node.hasFocus) _activeFieldId = id;
      else if (_activeFieldId == id) _activeFieldId = 'none';
    });
  }

  void _onTextChanged(String text, String fieldId) {
    if (_activeFieldId != fieldId) return;
    _debounce?.cancel();
    if (text.trim().length < 2) {
      if (_suggestions.isNotEmpty || _isSearching) {
        setState(() { _suggestions = []; _isSearching = false; });
      }
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _searchLocations(text, fieldId));
  }

  Future<void> _searchLocations(String query, String fieldId) async {
    if (!mounted) return;
    try {
      final locations = await locationFromAddress(query);
      if (!mounted || _activeFieldId != fieldId) return;
      final results = <_Suggestion>[];
      for (final loc in locations.take(5)) {
        String label = query;
        String detail = '';
        try {
          final pms = await placemarkFromCoordinates(loc.latitude, loc.longitude);
          if (pms.isNotEmpty) {
            final p = pms.first;
            final parts = [p.name, p.subLocality, p.locality, p.administrativeArea]
                .where((e) => e != null && e.isNotEmpty)
                .cast<String>()
                .toList();
            if (parts.isNotEmpty) label = parts.first;
            if (parts.length > 1) detail = parts.skip(1).take(2).join(', ');
          }
        } catch (e) { debugPrint('❌ Error: $e'); }
        if (detail.isEmpty) {
          detail = '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';
        }
        results.add(_Suggestion(label: label, detail: detail, lat: loc.latitude, lng: loc.longitude));
      }
      if (mounted) setState(() { _suggestions = results; _isSearching = false; });
    } catch (e) { debugPrint('❌ Error: $e');
      if (mounted) setState(() { _suggestions = []; _isSearching = false; });
    }
  }

   void _onSuggestionTap(_Suggestion s) {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _isSearching = false;
      if (_activeFieldId == 'origin') {
        _originLat = s.lat; _originLng = s.lng; _originAddress = s.label;
        _originCtrl.text = s.label;
      } else if (_activeFieldId == 'destination') {
        _destLat = s.lat; _destLng = s.lng; _destAddress = s.label;
        _destCtrl.text = s.label;
      } else if (_activeFieldId.startsWith('waypoint_')) {
        final idx = int.tryParse(_activeFieldId.split('_').last) ?? -1;
        if (idx >= 0 && idx < _waypoints.length) {
          _waypoints[idx].lat = s.lat;
          _waypoints[idx].lng = s.lng;
          _waypoints[idx].address = s.label;
          _waypoints[idx].ctrl.text = s.label;
        }
      }
    });
    _fitMapToBothPoints();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_originLat == null || _destLat == null) {
      _drawCtrl?.stop();
      if (_routePoints.isNotEmpty) setState(() { _routePoints = []; _visiblePoints = []; });
      return;
    }
    final waypointsToPass = _waypoints
        .where((w) => w.lat != null && w.lng != null)
        .map((w) => LatLng(w.lat!, w.lng!))
        .toList();

    final result = await DirectionsService.getRoute(
      originLat: _originLat!, originLng: _originLng!,
      destLat: _destLat!, destLng: _destLng!,
      waypoints: waypointsToPass.isNotEmpty ? waypointsToPass : null,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted) return;
    setState(() { _routePoints = result?.points ?? []; _visiblePoints = []; });
    if (_routePoints.isNotEmpty) _drawCtrl?.forward(from: 0.0);
  }

  void _onDrawFrame() {
    if (_routePoints.isEmpty || _drawCtrl == null) return;
    final count = (_drawCtrl!.value * _routePoints.length).ceil().clamp(2, _routePoints.length);
    setState(() => _visiblePoints = _routePoints.sublist(0, count));
  }

  Future<void> _fitMapToBothPoints() async {
    if (!_mapCtrl.isCompleted) return;
    final ctrl = await _mapCtrl.future;
    if (_originLat != null && _destLat != null) {
      double minLat = math.min(_originLat!, _destLat!);
      double maxLat = math.max(_originLat!, _destLat!);
      double minLng = math.min(_originLng!, _destLng!);
      double maxLng = math.max(_originLng!, _destLng!);
      
      for (final w in _waypoints) {
        if (w.lat != null && w.lng != null) {
          minLat = math.min(minLat, w.lat!);
          maxLat = math.max(maxLat, w.lat!);
          minLng = math.min(minLng, w.lng!);
          maxLng = math.max(maxLng, w.lng!);
        }
      }

      ctrl.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        80,
      ));
    }
  }

  void _enterPickMode(_PickMode mode, {int waypointIdx = -1}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _pickMode = mode;
      _pickWaypointIdx = waypointIdx;
      _suggestions = [];
      _isSearching = false;
    });
  }

  void _onCameraMove(CameraPosition pos) {
    if (_pickMode != _PickMode.none) {
      _mapCenter = pos.target;
      _reverseDebounce?.cancel();
      if (!_isReversing) setState(() => _isReversing = true);
      _reverseDebounce = Timer(const Duration(milliseconds: 700), () async {
        try {
          final pms = await placemarkFromCoordinates(_mapCenter.latitude, _mapCenter.longitude);
          String addr = '';
          if (pms.isNotEmpty) {
            final p = pms.first;
            final parts = [p.street, p.subLocality, p.locality]
                .where((e) => e != null && e.isNotEmpty).cast<String>().toList();
            if (parts.isNotEmpty) addr = parts.join(', ');
          }
          if (mounted) setState(() { _livePickAddress = addr; _isReversing = false; });
        } catch (e) { debugPrint('❌ Error: $e');
          if (mounted) setState(() => _isReversing = false);
        }
      });
    }
  }

  Future<void> _confirmPickLocation() async {
    setState(() => _isPickConfirming = true);
    try {
      String addr = _livePickAddress.isNotEmpty
          ? _livePickAddress
          : '${_mapCenter.latitude.toStringAsFixed(4)}, ${_mapCenter.longitude.toStringAsFixed(4)}';
      if (_livePickAddress.isEmpty) {
        try {
          final pms = await placemarkFromCoordinates(_mapCenter.latitude, _mapCenter.longitude);
          if (pms.isNotEmpty) {
            final p = pms.first;
            final parts = [p.street, p.subLocality, p.locality]
                .where((e) => e != null && e.isNotEmpty).cast<String>().toList();
            if (parts.isNotEmpty) addr = parts.join(', ');
          }
        } catch (e) { debugPrint('❌ Error: $e'); }
      }
      if (!mounted) return;
      setState(() {
        if (_pickMode == _PickMode.origin) {
          _originLat = _mapCenter.latitude; _originLng = _mapCenter.longitude;
          _originAddress = addr; _originCtrl.text = addr;
        } else if (_pickMode == _PickMode.destination) {
          _destLat = _mapCenter.latitude; _destLng = _mapCenter.longitude;
          _destAddress = addr; _destCtrl.text = addr;
        } else if (_pickMode == _PickMode.waypoint && _pickWaypointIdx >= 0 && _pickWaypointIdx < _waypoints.length) {
          _waypoints[_pickWaypointIdx].lat = _mapCenter.latitude;
          _waypoints[_pickWaypointIdx].lng = _mapCenter.longitude;
          _waypoints[_pickWaypointIdx].address = addr;
          _waypoints[_pickWaypointIdx].ctrl.text = addr;
        }
        _pickMode = _PickMode.none;
        _livePickAddress = '';
        _isPickConfirming = false;
      });
      _fitMapToBothPoints();
      _fetchRoute();
    } catch (e) { debugPrint('❌ Error: $e');
      if (mounted) {
        setState(() {
          _pickMode = _PickMode.none;
          _livePickAddress = '';
          _isPickConfirming = false;
        });
      }
    }
  }

  void _swapLocations() {
    if (_originLat == null && _destLat == null) return;
    setState(() {
      final tmpLat = _originLat; final tmpLng = _originLng; final tmpAddr = _originAddress;
      _originLat = _destLat; _originLng = _destLng; _originAddress = _destAddress;
      _destLat = tmpLat; _destLng = tmpLng; _destAddress = tmpAddr;
      _originCtrl.text = _originAddress ?? '';
      _destCtrl.text = _destAddress ?? '';
    });
    _fitMapToBothPoints();
    _fetchRoute();
  }

  void _confirm() {
    if (_originLat == null || _destLat == null) {
      AppToast.error(AppLocalizations.of(context)!.pleaseSelectOriginAndDest);
      return;
    }
    
    final validWaypoints = _waypoints
        .where((w) => w.lat != null && w.lng != null)
        .map((w) => WaypointArg(lat: w.lat!, lng: w.lng!, address: w.address ?? ''))
        .toList();

    context.push(AppRoutes.userPricing, extra: PricingArgs(
      originLat: _originLat!, originLng: _originLng!,
      originAddress: _originAddress ?? '',
      destLat: _destLat!, destLng: _destLng!,
      destAddress: _destAddress ?? '',
      waypoints: validWaypoints.isNotEmpty ? validWaypoints : null,
    ));
  }

  @override
  void dispose() {
    _cardPulseCtrl?.dispose();
    _drawCtrl?.dispose();
    _reverseDebounce?.cancel();
    _debounce?.cancel();
    _originCtrl.dispose(); _destCtrl.dispose();
    _originFocus.dispose(); _destFocus.dispose();
    for (var w in _waypoints) { w.dispose(); }
    super.dispose();
  }

  bool get _showSuggestions =>
      (_isSearching || _suggestions.isNotEmpty) && _pickMode == _PickMode.none;

  

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        if (state is LocationSelected && _originLat == null) {
          setState(() {
            _originLat = state.lat; _originLng = state.lng;
            _originAddress = state.address;
            _originCtrl.text = state.address;
          });
          _mapCtrl.future.then((c) => c.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(state.lat, state.lng), 15)));
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(child: _buildMap(isDark)),

            // Top gradient
            Positioned(
              top: 0, left: 0, right: 0, height: 200,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [AppColors.black.withValues(alpha: 0.55), AppColors.transparent]
                          : [AppColors.white.withValues(alpha: 0.45), AppColors.transparent],
                    ),
                  ),
                ),
              ),
            ),

            // Top card or pick banner
            Positioned(
              top: 0, left: 0, right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pickMode == _PickMode.none)
                    _buildTopCard(isDark)
                  else
                    _buildPickModeBanner(isDark),
                  if (_showSuggestions) _buildSuggestions(isDark),
                ],
              ),
            ),

            // Center pin in pick mode
            if (_pickMode != _PickMode.none)
              Positioned.fill(child: _buildCenterPin()),

            // Bottom actions
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: SafeArea(
                top: false,
                child: _pickMode != _PickMode.none
                    ? _buildPickModeDialog(isDark)
                    : _buildConfirmButton(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  Widget _buildTopCard(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PremiumBackButton(isDark: isDark, onTap: () => context.pop()),
            const SizedBox(width: 10),
            Expanded(
              child: _PremiumCard(
                isDark: isDark,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline dots
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _RouteTimeline(
                          waypointCount: _waypoints.length,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Fields column
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ORIGIN
                            _SlimField(
                              controller: _originCtrl,
                              focusNode: _originFocus,
                              label: AppLocalizations.of(context)!.origin,
                              placeholder: AppLocalizations.of(context)!.searchOrPick,
                              isActive: _activeFieldId == 'origin',
                              isDark: isDark,
                              trailingIcon: Icons.my_location_rounded,
                              onTrailingTap: () => _enterPickMode(_PickMode.origin),
                            ),

                            // WAYPOINTS
                            ..._waypoints.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final w = entry.value;
                              return _SlimField(
                                controller: w.ctrl,
                                focusNode: w.focus,
                                label: 'محطة ${idx + 1}',
                                placeholder: 'ابحث أو اختر من الخريطة',
                                isActive: _activeFieldId == 'waypoint_$idx',
                                isDark: isDark,
                                trailingIcon: Icons.location_searching_rounded,
                                onTrailingTap: () => _enterPickMode(_PickMode.waypoint, waypointIdx: idx),
                                showRemove: true,
                                onRemove: () {
                                  setState(() {
                                    w.dispose();
                                    _waypoints.removeAt(idx);
                                  });
                                  _fetchRoute();
                                },
                              );
                            }),

                            // DESTINATION
                            _SlimField(
                              controller: _destCtrl,
                              focusNode: _destFocus,
                              label: AppLocalizations.of(context)!.destination,
                              placeholder: AppLocalizations.of(context)!.whereToGoQ,
                              isActive: _activeFieldId == 'destination',
                              isDark: isDark,
                              trailingIcon: Icons.location_on_rounded,
                              onTrailingTap: () => _enterPickMode(_PickMode.destination),
                              isLast: true,
                            ),

                            // Add waypoint + swap row
                            if (_waypoints.length < 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 2),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          final w = _WaypointModel();
                                          _waypoints.add(w);
                                          w.ctrl.addListener(() {
                                            final idx = _waypoints.indexOf(w);
                                            if (idx >= 0) _onTextChanged(w.ctrl.text, 'waypoint_$idx');
                                          });
                                          w.focus.addListener(() {
                                            final idx = _waypoints.indexOf(w);
                                            if (idx >= 0) _onFocusChanged('waypoint_$idx', w.focus);
                                          });
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_rounded, size: 13, color: AppColors.primary),
                                            const SizedBox(width: 3),
                                            Text('إضافة محطة',
                                              style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: _swapLocations,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppColors.white.withValues(alpha: 0.05)
                                              : AppColors.black.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.swap_vert_rounded, size: 13, color: context.textSecondary),
                                            const SizedBox(width: 3),
                                            Text('عكس',
                                              style: TextStyle(fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(bool isDark) {
    final canConfirm = _originLat != null && _destLat != null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: canConfirm ? _confirm : null,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: canConfirm ? 12 : 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.50),
          backgroundColor: canConfirm ? AppColors.primary : (isDark ? AppColors.divider : AppColors.textPrimary),
          foregroundColor: canConfirm ? AppColors.white : (isDark ? AppColors.white.withValues(alpha: 0.38) : AppColors.black.withValues(alpha: 0.38)),
          disabledBackgroundColor: isDark ? AppColors.divider : AppColors.textPrimary,
          disabledForegroundColor: isDark ? AppColors.white.withValues(alpha: 0.38) : AppColors.black.withValues(alpha: 0.38),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              canConfirm ? AppLocalizations.of(context)!.confirmAndCalculate : AppLocalizations.of(context)!.selectOriginAndDest,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            if (canConfirm) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 13),
            ],
          ],
        ),
      ),
    );
  }

  

  Widget _buildPickModeBanner(bool isDark) {
    final isOrigin = _pickMode == _PickMode.origin;
    final isWaypoint = _pickMode == _PickMode.waypoint;
    final color = isOrigin ? AppColors.success : (isWaypoint ? AppColors.warning : AppColors.error);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.background : AppColors.white).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6)),
                  BoxShadow(color: AppColors.black.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() { _pickMode = _PickMode.none; _livePickAddress = ''; }),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: context.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  
                  AnimatedBuilder(
                    animation: _cardPulseAnim ?? const AlwaysStoppedAnimation(0.0),
                    builder: (_, __) {
                      final v = _cardPulseAnim?.value ?? 0.0;
                      return Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3 + 0.4 * v),
                              blurRadius: 4 + 6 * v,
                              spreadRadius: v * 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isOrigin
                          ? AppLocalizations.of(context)!.moveMapForOrigin
                          : (isWaypoint
                              ? 'حرّك الخريطة لاختيار المحطة'
                              : AppLocalizations.of(context)!.moveMapForDest),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  

  Widget _buildSuggestions(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.background : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.white.withValues(alpha: 0.06) : AppColors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.black.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: AppColors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: _isSearching && _suggestions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: context.divColor,
                    indent: 56,
                    endIndent: 16,
                  ),
                  itemBuilder: (ctx, i) {
                    final s = _suggestions[i];
                    return InkWell(
                      onTap: () => _onSuggestionTap(s),
                      splashColor: AppColors.primary.withValues(alpha: 0.06),
                      highlightColor: AppColors.primary.withValues(alpha: 0.04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: context.primaryTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 17),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.label,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (s.detail.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      s.detail,
                                      style: TextStyle(color: context.textSecondary, fontSize: 11.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.north_west_rounded, size: 13, color: context.textSecondary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  

  Widget _buildMap(bool isDark) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    if (_originLat != null) {
      markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(_originLat!, _originLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: _originAddress ?? AppLocalizations.of(context)!.startingPoint),
      ));
    }
    if (_destLat != null) {
      markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: LatLng(_destLat!, _destLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: _destAddress ?? AppLocalizations.of(context)!.destination),
      ));
    }
    if (_originLat != null && _destLat != null && _visiblePoints.length >= 2) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route_halo'),
        points: _visiblePoints,
        color: AppColors.primary.withValues(alpha: 0.10),
        width: 18,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route_glow'),
        points: _visiblePoints,
        color: AppColors.primary.withValues(alpha: 0.28),
        width: 10,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _visiblePoints,
        color: AppColors.primary,
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }
    return GoogleMap(
      initialCameraPosition: _defaultCamera,
      onMapCreated: (ctrl) { if (!_mapCtrl.isCompleted) _mapCtrl.complete(ctrl); },
      onCameraMove: _onCameraMove,
      onTap: _pickMode == _PickMode.none ? (pos) async {
        try {
          final pms = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          final parts = pms.isNotEmpty
              ? [pms.first.street, pms.first.subLocality, pms.first.locality]
                  .where((e) => e != null && e.isNotEmpty).cast<String>().toList()
              : <String>[];
          final addr = parts.isNotEmpty
              ? parts.join(', ')
              : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          if (!mounted) return;
          setState(() {
            if (_activeFieldId == 'origin' || _originLat == null) {
              _originLat = pos.latitude; _originLng = pos.longitude;
              _originAddress = addr; _originCtrl.text = addr;
            } else if (_activeFieldId == 'destination') {
              _destLat = pos.latitude; _destLng = pos.longitude;
              _destAddress = addr; _destCtrl.text = addr;
            } else if (_activeFieldId.startsWith('waypoint_')) {
              final idx = int.tryParse(_activeFieldId.split('_').last) ?? -1;
              if (idx >= 0 && idx < _waypoints.length) {
                _waypoints[idx].lat = pos.latitude;
                _waypoints[idx].lng = pos.longitude;
                _waypoints[idx].address = addr;
                _waypoints[idx].ctrl.text = addr;
              }
            }
          });
          _fitMapToBothPoints();
          _fetchRoute();
        } catch (e) { debugPrint('❌ Error: $e'); }
      } : null,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: markers,
      polylines: polylines,
      padding: const EdgeInsets.only(top: 180, bottom: 80),
      style: isDark ? kDarkMapStyle : kLightMapStyle,
    );
  }

  

  Widget _buildCenterPin() {
    final isOrigin = _pickMode == _PickMode.origin;
    final isWaypoint = _pickMode == _PickMode.waypoint;
    final color = isOrigin ? AppColors.success : (isWaypoint ? AppColors.warning : AppColors.error);
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            
            AnimatedBuilder(
              animation: _cardPulseAnim ?? const AlwaysStoppedAnimation(0.0),
              builder: (_, child) {
                final v = _cardPulseAnim?.value ?? 0.0;
                return Container(
                  width: 52 + 8 * v,
                  height: 52 + 8 * v,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08 + 0.06 * (1 - v)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.3 + 0.15 * (1 - v)),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 0),
            
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.location_on_rounded, color: AppColors.white, size: 22),
            ),
            
            Container(
              width: 2.5, height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Container(
              width: 12, height: 5,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  


  Widget _buildPickModeDialog(bool isDark) {
    final isOrigin = _pickMode == _PickMode.origin;
    final isWaypoint = _pickMode == _PickMode.waypoint;
    final color = isOrigin ? AppColors.success : (isWaypoint ? AppColors.warning : AppColors.error);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.background : AppColors.white).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? AppColors.white.withValues(alpha: 0.07) : AppColors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(color: AppColors.black.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, 8)),
              BoxShadow(color: AppColors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: _cardPulseAnim ?? const AlwaysStoppedAnimation(0.0),
                    builder: (_, __) {
                      final v = _cardPulseAnim?.value ?? 0.0;
                      return Container(
                        width: 10, height: 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3 + 0.4 * v),
                              blurRadius: 4 + 8 * v,
                              spreadRadius: v * 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOrigin
                              ? AppLocalizations.of(context)!.startingPoint
                              : (isWaypoint
                                  ? 'محطة التوقف'
                                  : AppLocalizations.of(context)!.destination),
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        if (_isReversing)
                          Row(children: [
                            SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: color),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.locatingPosition,
                              style: TextStyle(color: context.textSecondary, fontSize: 12.5),
                            ),
                          ])
                        else
                          Text(
                            _livePickAddress.isNotEmpty ? _livePickAddress : AppLocalizations.of(context)!.moveMapToSelect,
                            style: TextStyle(
                              color: _livePickAddress.isNotEmpty ? context.textPrimary : context.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _pickMode = _PickMode.none; _livePickAddress = ''; }),
                    child: Container(
                      height: 48, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.elevatedColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.divColor),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.cancel,
                        style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isPickConfirming ? null : _confirmPickLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 6,
                        shadowColor: color.withValues(alpha: 0.45),
                      ),
                      child: _isPickConfirming
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              isOrigin
                                  ? AppLocalizations.of(context)!.confirmOrigin
                                  : (isWaypoint ? 'تأكيد المحطة' : AppLocalizations.of(context)!.confirmDest),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}



class _PremiumBackButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _PremiumBackButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: isDark ? AppColors.background : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: isDark
                ? AppColors.white.withValues(alpha: 0.07)
                : AppColors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 17,
          color: context.textPrimary,
        ),
      ),
    );
  }
}



class _PremiumCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _PremiumCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.background, AppColors.background]
              : [AppColors.white, AppColors.textPrimary],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.white.withValues(alpha: 0.07)
              : AppColors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: isDark ? 0.40 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.07 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }
}



class _SwapDivider extends StatelessWidget {
  final bool isDark;
  final VoidCallback onSwap;

  const _SwapDivider({required this.isDark, required this.onSwap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(
            child: Divider(color: context.divColor, height: 1, thickness: 1),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSwap,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: isDark ? AppColors.divider : AppColors.textPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: context.divColor, width: 1),
              ),
              child: Icon(
                Icons.swap_vert_rounded,
                size: 12,
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}



class _LocationField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final String label;
  final String placeholder;
  final Color dotColor;
  final bool isActive;
  final VoidCallback onMapTap;
  final bool isDark;

  const _LocationField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.label,
    required this.placeholder,
    required this.dotColor,
    required this.isActive,
    required this.onMapTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.primary.withValues(alpha: 0.04))
            : AppColors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: isActive ? 10 : 8,
            height: isActive ? 10 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? dotColor : dotColor.withValues(alpha: 0.4),
              boxShadow: isActive
                  ? [BoxShadow(color: dotColor.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isActive ? dotColor : context.textSecondary,
                    
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    height: 1,
                  ),
                  child: Text(label),
                ),
                
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: context.textPrimary,
                    
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    
                    contentPadding: const EdgeInsets.symmetric(vertical: 3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          
          GestureDetector(
            onTap: onMapTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : (isDark
                        ? AppColors.white.withValues(alpha: 0.05)
                        : AppColors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(10),
                border: isActive
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1)
                    : Border.all(
                        color: isDark
                            ? AppColors.white.withValues(alpha: 0.06)
                            : AppColors.black.withValues(alpha: 0.06),
                      ),
              ),
              child: Icon(
                Icons.location_searching_rounded,
                
                size: 15,
                color: isActive ? AppColors.primary : context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Route Timeline Widget ────────────────────────────────────────────────────
// Visual vertical timeline: green dot (origin) → dashed line → orange dots
// (waypoints) → dashed line → red dot (destination)
class _RouteTimeline extends StatelessWidget {
  final int waypointCount;
  final bool isDark;
  const _RouteTimeline({required this.waypointCount, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Each field row is ~52px tall
    const rowH = 52.0;
    const dotR = 7.0;
    final totalRows = 2 + waypointCount; // origin + waypoints + dest

    return SizedBox(
      width: 16,
      height: totalRows * rowH,
      child: CustomPaint(
        painter: _TimelinePainter(
          waypointCount: waypointCount,
          isDark: isDark,
          rowH: rowH,
          dotR: dotR,
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final int waypointCount;
  final bool isDark;
  final double rowH;
  final double dotR;

  _TimelinePainter({
    required this.waypointCount,
    required this.isDark,
    required this.rowH,
    required this.dotR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final totalRows = 2 + waypointCount;

    // Colors
    const originColor  = AppColors.success;  // green
    const waypointColor = AppColors.warning; // orange
    const destColor    = AppColors.error;    // red
    final lineColor = isDark
        ? AppColors.divider
        : AppColors.divider;

    // Draw connecting lines between dots
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < totalRows - 1; i++) {
      final y1 = rowH * i + rowH / 2 + dotR;
      final y2 = rowH * (i + 1) + rowH / 2 - dotR;
      // dashed line
      double y = y1;
      const dashH = 4.0;
      const gapH = 3.0;
      while (y < y2) {
        final end = (y + dashH).clamp(y, y2);
        canvas.drawLine(Offset(cx, y), Offset(cx, end), linePaint);
        y += dashH + gapH;
      }
    }

    // Draw dots
    for (int i = 0; i < totalRows; i++) {
      final cy = rowH * i + rowH / 2;
      Color dotColor;
      if (i == 0) {
        dotColor = originColor;
      } else if (i == totalRows - 1) {
        dotColor = destColor;
      } else {
        dotColor = waypointColor;
      }

      // Outer glow ring
      final glowPaint = Paint()
        ..color = dotColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), dotR + 3, glowPaint);

      // Dot fill
      final fillPaint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), dotR, fillPaint);

      // White inner dot
      final innerPaint = Paint()
        ..color = AppColors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), dotR * 0.38, innerPaint);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.waypointCount != waypointCount || old.isDark != isDark;
}

// ─── Slim Field Widget ────────────────────────────────────────────────────────
// Compact field with active left-border indicator, label above text input
class _SlimField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String placeholder;
  final bool isActive;
  final bool isDark;
  final IconData trailingIcon;
  final VoidCallback onTrailingTap;
  final bool isLast;
  final bool showRemove;
  final VoidCallback? onRemove;

  const _SlimField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.placeholder,
    required this.isActive,
    required this.isDark,
    required this.trailingIcon,
    required this.onTrailingTap,
    this.isLast = false,
    this.showRemove = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: isDark ? 0.09 : 0.05)
            : AppColors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.30), width: 1)
            : Border.all(color: AppColors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text field area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: isActive ? AppColors.primary : context.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  child: Text(label.toUpperCase()),
                ),
                const SizedBox(height: 1),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13.5,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          // Map pick button
          GestureDetector(
            onTap: onTrailingTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark
                        ? AppColors.white.withValues(alpha: 0.05)
                        : AppColors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                trailingIcon,
                size: 14,
                color: isActive ? AppColors.primary : context.textSecondary,
              ),
            ),
          ),

          // Remove button (for waypoints)
          if (showRemove && onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.close, size: 12, color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}