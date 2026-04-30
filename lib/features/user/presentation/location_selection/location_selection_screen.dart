// lib/features/user/presentation/location_selection/location_selection_screen.dart
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

// ─── Models ───────────────────────────────────────────────────────────────────

enum _ActiveField { none, origin, destination }
enum _PickMode { none, origin, destination }

class _Suggestion {
  final String label;
  final String detail;
  final double lat, lng;
  const _Suggestion({required this.label, required this.detail, required this.lat, required this.lng});
}

// ─── Shared map styles used across all map screens ───────────────────────────

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

  _ActiveField _activeField = _ActiveField.none;
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

  // Animation controllers for premium feel
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
    _originFocus.addListener(_onFocusChanged);
    _destFocus.addListener(_onFocusChanged);
    _originCtrl.addListener(() => _onTextChanged(_originCtrl.text, _ActiveField.origin));
    _destCtrl.addListener(() => _onTextChanged(_destCtrl.text, _ActiveField.destination));
  }

  void _onFocusChanged() {
    setState(() {
      if (_originFocus.hasFocus) _activeField = _ActiveField.origin;
      else if (_destFocus.hasFocus) _activeField = _ActiveField.destination;
      else _activeField = _ActiveField.none;
    });
  }

  void _onTextChanged(String text, _ActiveField field) {
    if (_activeField != field) return;
    _debounce?.cancel();
    if (text.trim().length < 2) {
      if (_suggestions.isNotEmpty || _isSearching) {
        setState(() { _suggestions = []; _isSearching = false; });
      }
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () => _searchLocations(text, field));
  }

  Future<void> _searchLocations(String query, _ActiveField field) async {
    if (!mounted) return;
    try {
      final locations = await locationFromAddress(query);
      if (!mounted || _activeField != field) return;
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
      if (_activeField == _ActiveField.origin) {
        _originLat = s.lat; _originLng = s.lng; _originAddress = s.label;
        _originCtrl.text = s.label;
      } else {
        _destLat = s.lat; _destLng = s.lng; _destAddress = s.label;
        _destCtrl.text = s.label;
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
    final result = await DirectionsService.getRoute(
      originLat: _originLat!, originLng: _originLng!,
      destLat: _destLat!, destLng: _destLng!,
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
      final minLat = math.min(_originLat!, _destLat!);
      final maxLat = math.max(_originLat!, _destLat!);
      final minLng = math.min(_originLng!, _destLng!);
      final maxLng = math.max(_originLng!, _destLng!);
      
      // Calculate delta between points
      final latDelta = maxLat - minLat;
      final lngDelta = maxLng - minLng;
      
      // Add 30% padding around the bounds, minimum 0.005 degrees
      final latPadding = math.max(latDelta * 0.3, 0.005);
      final lngPadding = math.max(lngDelta * 0.3, 0.005);
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
      
      ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else if (_destLat != null) {
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_destLat!, _destLng!), 15));
    } else if (_originLat != null) {
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_originLat!, _originLng!), 15));
    }
  }

  void _enterPickMode(_PickMode mode) {
    FocusScope.of(context).unfocus();
    setState(() {
      _pickMode = mode;
      _suggestions = [];
      _livePickAddress = '';
      _isReversing = false;
    });
  }

  void _onCameraMove(CameraPosition pos) {
    if (_pickMode == _PickMode.none) return;
    _mapCenter = pos.target;
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted || _pickMode == _PickMode.none) return;
      setState(() => _isReversing = true);
      try {
        final pms = await placemarkFromCoordinates(pos.target.latitude, pos.target.longitude);
        if (!mounted) return;
        String addr = '${pos.target.latitude.toStringAsFixed(4)}, ${pos.target.longitude.toStringAsFixed(4)}';
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
        } else {
          _destLat = _mapCenter.latitude; _destLng = _mapCenter.longitude;
          _destAddress = addr; _destCtrl.text = addr;
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
    context.push(AppRoutes.userPricing, extra: PricingArgs(
      originLat: _originLat!, originLng: _originLng!,
      originAddress: _originAddress ?? '',
      destLat: _destLat!, destLng: _destLng!,
      destAddress: _destAddress ?? '',
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
    super.dispose();
  }

  bool get _showSuggestions =>
      (_isSearching || _suggestions.isNotEmpty) && _pickMode == _PickMode.none;

  // ─── Build ─────────────────────────────────────────────────────────────────

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
            // ── Full-screen map
            Positioned.fill(child: _buildMap(isDark)),

            // ── Top gradient overlay for readability
            Positioned(
              top: 0, left: 0, right: 0,
              height: 200,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [Colors.black.withValues(alpha: 0.55), Colors.transparent]
                          : [Colors.white.withValues(alpha: 0.45), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top floating UI
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

            // ── Center pin for pick mode
            if (_pickMode != _PickMode.none)
              Positioned.fill(child: _buildCenterPin()),

            // ── Bottom actions
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: SafeArea(top: false, child: _buildBottomActions()),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Premium top card — compact & refined ──────────────────────────────────

  Widget _buildTopCard(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        // ← Reduced outer padding: was fromLTRB(12,10,12,10)
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Back button — premium pill style
            _PremiumBackButton(isDark: isDark, onTap: () => context.pop()),
            const SizedBox(width: 10),

            // ── Fields card
            Expanded(
              child: _PremiumCard(
                isDark: isDark,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Origin field
                    _LocationField(
                      controller: _originCtrl,
                      focusNode: _originFocus,
                      hint: AppLocalizations.of(context)!.startingPoint,
                      label: AppLocalizations.of(context)!.origin,
                      placeholder: AppLocalizations.of(context)!.searchOrPick,
                      dotColor: AppColors.success,
                      isActive: _activeField == _ActiveField.origin,
                      onMapTap: () => _enterPickMode(_PickMode.origin),
                      isDark: isDark,
                    ),

                    // Slim divider with centered swap
                    _SwapDivider(isDark: isDark, onSwap: _swapLocations),

                    // Destination field
                    _LocationField(
                      controller: _destCtrl,
                      focusNode: _destFocus,
                      hint: AppLocalizations.of(context)!.destination,
                      label: AppLocalizations.of(context)!.destination,
                      placeholder: AppLocalizations.of(context)!.whereToGoQ,
                      dotColor: AppColors.error,
                      isActive: _activeField == _ActiveField.destination,
                      onMapTap: () => _enterPickMode(_PickMode.destination),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Pick mode instruction banner ──────────────────────────────────────────

  Widget _buildPickModeBanner(bool isDark) {
    final isOrigin = _pickMode == _PickMode.origin;
    final color = isOrigin ? AppColors.success : AppColors.error;
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
                color: (isDark ? const Color(0xFF0D1526) : Colors.white).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() { _pickMode = _PickMode.none; _livePickAddress = ''; }),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: context.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  // Animated dot
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
                      isOrigin ? AppLocalizations.of(context)!.moveMapForOrigin : AppLocalizations.of(context)!.moveMapForDest,
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

  // ─── Suggestions dropdown ──────────────────────────────────────────────────

  Widget _buildSuggestions(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1526) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
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

  // ─── Map ───────────────────────────────────────────────────────────────────

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
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route_glow'),
        points: _visiblePoints,
        color: AppColors.primary.withValues(alpha: 0.28),
        width: 10,
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _visiblePoints,
        color: AppColors.primary,
        width: 4,
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
            if (_activeField == _ActiveField.origin || _originLat == null) {
              _originLat = pos.latitude; _originLng = pos.longitude;
              _originAddress = addr; _originCtrl.text = addr;
            } else {
              _destLat = pos.latitude; _destLng = pos.longitude;
              _destAddress = addr; _destCtrl.text = addr;
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

  // ─── Center pin for pick mode ──────────────────────────────────────────────

  Widget _buildCenterPin() {
    final isOrigin = _pickMode == _PickMode.origin;
    final color = isOrigin ? AppColors.success : AppColors.error;
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated outer ring
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
            // Inner pin
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
            ),
            // Pin stem
            Container(
              width: 2.5, height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Shadow ellipse
            Container(
              width: 12, height: 5,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom action buttons ─────────────────────────────────────────────────

  Widget _buildBottomActions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_pickMode != _PickMode.none) {
      return _buildPickModeDialog(isDark);
    }
    final canConfirm = _originLat != null && _destLat != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: canConfirm
            ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
            : ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: canConfirm ? _confirm : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: canConfirm ? 12 : 0,
              shadowColor: AppColors.primary.withValues(alpha: 0.50),
              backgroundColor: canConfirm
                  ? AppColors.primary
                  : (isDark ? const Color(0xFF1A2A40) : const Color(0xFFE8EEF5)),
              foregroundColor: canConfirm
                  ? Colors.white
                  : (isDark ? Colors.white38 : Colors.black38),
              disabledBackgroundColor: isDark ? const Color(0xFF1A2A40) : const Color(0xFFE8EEF5),
              disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
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
        ),
      ),
    );
  }

  Widget _buildPickModeDialog(bool isDark) {
    final isOrigin = _pickMode == _PickMode.origin;
    final color = isOrigin ? AppColors.success : AppColors.error;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0D1526) : Colors.white).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, 8)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
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
                          isOrigin ? AppLocalizations.of(context)!.startingPoint : AppLocalizations.of(context)!.destination,
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
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 6,
                        shadowColor: color.withValues(alpha: 0.45),
                      ),
                      child: _isPickConfirming
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              isOrigin ? AppLocalizations.of(context)!.confirmOrigin : AppLocalizations.of(context)!.confirmDest,
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

// ─── Premium Back Button ──────────────────────────────────────────────────────

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
          color: isDark ? const Color(0xFF0D1526) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
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

// ─── Premium Card Container ───────────────────────────────────────────────────

class _PremiumCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _PremiumCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Subtle gradient background instead of flat color
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F1828), const Color(0xFF0B1220)]
              : [Colors.white, const Color(0xFFF8FAFD)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          // Subtle brand glow at the top edge
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

// ─── Swap Divider ─────────────────────────────────────────────────────────────

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
                color: isDark ? const Color(0xFF1A2A40) : const Color(0xFFF0F4FF),
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

// ─── Location Field — compact & premium ──────────────────────────────────────

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
      // ← Reduced vertical padding: was symmetric(horizontal:14, vertical:8)
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.primary.withValues(alpha: 0.04))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Animated dot indicator
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

          // ── Label + TextField stacked tightly
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tiny floating label
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isActive ? dotColor : context.textSecondary,
                    // ← Was 10px
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    height: 1,
                  ),
                  child: Text(label),
                ),
                // ← Was SizedBox(height:3)
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: context.textPrimary,
                    // ← Was 14.5px
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
                    // ← Tighter content padding
                    contentPadding: const EdgeInsets.symmetric(vertical: 3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Map pin button — slightly smaller
          GestureDetector(
            onTap: onMapTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              // ← Was 34x34
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(10),
                border: isActive
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1)
                    : Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
              ),
              child: Icon(
                Icons.location_searching_rounded,
                // ← Was 16
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