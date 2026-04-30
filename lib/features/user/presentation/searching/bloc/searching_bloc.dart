// lib/features/user/presentation/searching/bloc/searching_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../services/trip_broadcast_service.dart';
import '../../../../../core/utils/retry_helper.dart';
import 'searching_event.dart';
import 'searching_state.dart';

/// Searching BLoC — manages the 3-minute driver search flow.
///
/// Uses the cell system (via TripBroadcastService) to:
/// 1. Find nearby drivers in the same geohash cells
/// 2. Broadcast trip offers to all matching drivers
/// 3. Re-broadcast every 15s to newly-online drivers
/// 4. Listen for trip status changes via Supabase Realtime
class SearchingBloc extends Bloc<SearchingEvent, SearchingState> {
  Timer? _countdownTimer;
  Timer? _rebroadcastTimer;
  final TripBroadcastService _broadcastService =
      TripBroadcastService.instance;
  final Set<String> _broadcastedDriverIds = {};

  static const int _searchDurationSeconds = 180; // 3 minutes
  static const int _rebroadcastIntervalSeconds = 15;

  SearchingBloc() : super(SearchingInitial()) {
    on<StartSearching>(_onStart);
    on<TimerTick>(_onTick);
    on<TripStatusChanged>(_onTripChanged);
    on<CancelSearch>(_onCancel);
    on<RebroadcastTripOffers>(_onRebroadcast);
  }

  StreamSubscription? _tripSubscription;

  Future<void> _onStart(
    StartSearching event,
    Emitter<SearchingState> emit,
  ) async {
    debugPrint('🔍 SearchingBloc: StartSearching for trip ${event.tripId}');
    _broadcastedDriverIds.clear();

    // FIX C06: Cancel any existing timers before creating new ones
    _countdownTimer?.cancel();
    _rebroadcastTimer?.cancel();
    _tripSubscription?.cancel();

    // Start the 3-minute countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _searchDurationSeconds - timer.tick;
      if (remaining <= 0) timer.cancel();
      add(TimerTick(remaining.clamp(0, _searchDurationSeconds)));
    });

    emit(SearchingInProgress(
      remainingSeconds: _searchDurationSeconds,
      tripId: event.tripId,
    ));

    // Listen to trip status changes via Realtime
    _tripSubscription?.cancel();
    _tripSubscription = SupabaseService.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', event.tripId)
        .listen((rows) {
      if (rows.isNotEmpty) {
        add(TripStatusChanged(Map<String, dynamic>.from(rows.first)));
      }
    });

    // Initial broadcast
    await _performBroadcast(event.tripId);

    // Start periodic re-broadcast every 15s to catch newly-online drivers
    _rebroadcastTimer = Timer.periodic(
      const Duration(seconds: _rebroadcastIntervalSeconds),
      (_) => add(RebroadcastTripOffers(event.tripId)),
    );
  }

  Future<void> _performBroadcast(String tripId) async {
    debugPrint('🔍 SearchingBloc: Performing broadcast for trip $tripId');
    try {
      final tripDetails = await SupabaseService.client
          .from('trips')
          .select('pickup_lat, pickup_lng, vehicle_type, status')
          .eq('id', tripId)
          .single();

      if (tripDetails['status'] != 'searching') {
        debugPrint('🔍 SearchingBloc: Trip $tripId no longer searching, skipping broadcast');
        return;
      }

      debugPrint(
          '🔍 SearchingBloc: Trip $tripId - lat=${tripDetails['pickup_lat']}, lng=${tripDetails['pickup_lng']}, vehicle=${tripDetails['vehicle_type']}');

      final driverIds = await _broadcastService.findNearbyDrivers(
        originLat: (tripDetails['pickup_lat'] as num).toDouble(),
        originLng: (tripDetails['pickup_lng'] as num).toDouble(),
        vehicleType: (tripDetails['vehicle_type'] as String).trim().toLowerCase(),
      );

      // Only broadcast to drivers we haven't already sent to
      final newDriverIds = driverIds
          .where((id) => !_broadcastedDriverIds.contains(id))
          .toList();
      _broadcastedDriverIds.addAll(newDriverIds);

      debugPrint(
          '🔍 SearchingBloc: Found ${driverIds.length} total drivers, ${newDriverIds.length} new for trip $tripId');

      if (newDriverIds.isNotEmpty) {
        debugPrint('🔍 SearchingBloc: Broadcasting to new drivers: $newDriverIds');
        await _broadcastService.broadcastTripOffers(
          tripId: tripId,
          driverIds: newDriverIds,
        );
        debugPrint('🔍 SearchingBloc: Broadcast completed for trip $tripId');
      } else if (driverIds.isEmpty) {
        debugPrint('⚠️ SearchingBloc: No drivers found yet for trip $tripId, will retry...');
      }
    } catch (e) {
      debugPrint('❌ SearchingBloc: Error broadcasting trip: $e');
    }
  }

  Future<void> _onRebroadcast(
    RebroadcastTripOffers event,
    Emitter<SearchingState> emit,
  ) async {
    if (state is! SearchingInProgress) return;
    await _performBroadcast(event.tripId);
  }

  Future<void> _onTick(
    TimerTick event,
    Emitter<SearchingState> emit,
  ) async {
    if (event.remainingSeconds <= 0 && state is SearchingInProgress) {
      _countdownTimer?.cancel();
      _rebroadcastTimer?.cancel();
      // Mark trip as cancelled when timer expires (no driver found)
      try {
        final tripId = (state as SearchingInProgress).tripId;
        // FIX P0-05: Use cancel_trip RPC for atomic race-safe cancellation
        await withRetry(
          () => SupabaseService.client.rpc('cancel_trip', params: {
            'p_trip_id': tripId,
            'p_user_id': SupabaseService.currentUser!.id,
            'p_cancelled_by': 'system',
            'p_cancel_reason': 'timeout',
          }),
          maxAttempts: 2,
          onRetry: (e, attempt) => debugPrint('SearchingBloc: retry cancel #$attempt: $e'),
        );
      } catch (e) {
        debugPrint('SearchingBloc: error cancelling trip on timeout — $e');
      }
      emit(const SearchingNoDrivers());
    } else if (state is SearchingInProgress) {
      emit(SearchingInProgress(
        remainingSeconds: event.remainingSeconds,
        tripId: (state as SearchingInProgress).tripId,
      ));
    }
  }

  Future<void> _onTripChanged(
    TripStatusChanged event,
    Emitter<SearchingState> emit,
  ) async {
    final status = event.trip['status'] as String?;
    debugPrint('🔍 SearchingBloc: Trip status changed to: $status');
    switch (status) {
      case 'accepted':
      case 'in_progress':
        _countdownTimer?.cancel();
        _rebroadcastTimer?.cancel();
        emit(SearchingSuccess(trip: event.trip));
        break;
      case 'cancelled':
        _countdownTimer?.cancel();
        _rebroadcastTimer?.cancel();
        emit(const SearchingNoDrivers());
        break;
      case 'searching':
        debugPrint('🔍 SearchingBloc: Trip is currently searching, waiting for driver...');
        break;
      default:
        debugPrint('🔍 SearchingBloc: Unknown status: $status');
        break;
    }
  }

  Future<void> _onCancel(
    CancelSearch event,
    Emitter<SearchingState> emit,
  ) async {
    _countdownTimer?.cancel();
    _rebroadcastTimer?.cancel();
    await _tripSubscription?.cancel();
    try {
      // FIX P0-05: Use cancel_trip RPC for atomic race-safe cancellation
      await withRetry(
        () => SupabaseService.client.rpc('cancel_trip', params: {
          'p_trip_id': event.tripId,
          'p_user_id': SupabaseService.currentUser!.id,
          'p_cancelled_by': 'user',
        }),
        maxAttempts: 2,
        onRetry: (e, attempt) => debugPrint('SearchingBloc: retry cancel #$attempt: $e'),
      );
    } catch (e) {
      debugPrint('SearchingBloc: error cancelling trip — $e');
    }
    emit(SearchingCancelled());
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _rebroadcastTimer?.cancel();
    _tripSubscription?.cancel();
    return super.close();
  }
}
