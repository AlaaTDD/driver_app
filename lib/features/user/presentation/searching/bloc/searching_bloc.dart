import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/supabase_service.dart';
import '../../../../../core/services/trip_broadcast_service.dart';
import '../../../../../core/utils/retry_helper.dart';
import 'searching_event.dart';
import 'searching_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

class SearchingBloc extends Bloc<SearchingEvent, SearchingState> {
  Timer? _countdownTimer;
  Timer? _rebroadcastTimer;
  final TripBroadcastService _broadcastService = TripBroadcastService.instance;
  final Set<String> _broadcastedDriverIds = {};

  static const int _searchDurationSeconds = 180;
  static const int _rebroadcastIntervalSeconds = 15;

  SearchingBloc() : super(SearchingInitial()) {
    on<StartSearching>(_onStart);
    on<TimerTick>(_onTick);
    on<TripStatusChanged>(_onTripChanged);
    on<CancelSearch>(_onCancel);
    on<RebroadcastTripOffers>(_onRebroadcast);
    on<OffersUpdated>(_onOffersUpdated);
    on<AcceptDriverOffer>(_onAcceptDriverOffer);
  }

  StreamSubscription? _tripSubscription;
  StreamSubscription? _offersSubscription;

  Future<void> _onStart(
    StartSearching event,
    Emitter<SearchingState> emit,
  ) async {
    AppLogger.debug('🔍 SearchingBloc: StartSearching for trip ${event.tripId}');
    _broadcastedDriverIds.clear();

    _countdownTimer?.cancel();
    _rebroadcastTimer?.cancel();
    _tripSubscription?.cancel();
    _offersSubscription?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _searchDurationSeconds - timer.tick;
      if (remaining <= 0) timer.cancel();
      add(TimerTick(remaining.clamp(0, _searchDurationSeconds)));
    });

    emit(SearchingInProgress(
      remainingSeconds: _searchDurationSeconds,
      tripId: event.tripId,
    ));

    _tripSubscription?.cancel();
    _tripSubscription = SupabaseService.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', event.tripId)
        .listen((rows) {
          if (rows.isEmpty) {
            add(TripStatusChanged({
              'id': event.tripId,
              'status': 'cancelled',
            }));
          } else {
            add(TripStatusChanged(Map<String, dynamic>.from(rows.first)));
          }
        });

    _offersSubscription?.cancel();
    _offersSubscription = SupabaseService.client
        .from('trip_offers')
        .stream(primaryKey: ['id'])
        .eq('trip_id', event.tripId)
        .listen((rows) {
          final pendingRows =
              rows.where((r) => r['status'] == 'pending').toList();
          add(OffersUpdated(
              pendingRows.map((e) => Map<String, dynamic>.from(e)).toList()));
        });

    await _performBroadcast(event.tripId, event.title, event.body);

    _rebroadcastTimer = Timer.periodic(
      const Duration(seconds: _rebroadcastIntervalSeconds),
      (_) => add(RebroadcastTripOffers(event.tripId,
          title: event.title, body: event.body)),
    );
  }

  Future<void> _performBroadcast(
      String tripId, String title, String body) async {
    AppLogger.debug('🔍 SearchingBloc: Performing broadcast for trip $tripId');
    try {
      final tripDetails = await SupabaseService.client
          .from('trips')
          .select(
              'pickup_lat, pickup_lng, destination_lat, destination_lng, service_tier_name_snapshot, status')
          .eq('id', tripId)
          .single();

      if (tripDetails['status'] != 'searching') {
        AppLogger.debug(
            '🔍 SearchingBloc: Trip $tripId no longer searching, skipping broadcast');
        return;
      }

      AppLogger.debug(
          '🔍 SearchingBloc: Trip $tripId - lat=${tripDetails['pickup_lat']}, lng=${tripDetails['pickup_lng']}, tier=${tripDetails['service_tier_name_snapshot']}');

      final notifiedDriverIds = await _broadcastService.findAndBroadcast(
        tripId: tripId,
        originLat: (tripDetails['pickup_lat'] as num).toDouble(),
        originLng: (tripDetails['pickup_lng'] as num).toDouble(),
        destLat: (tripDetails['destination_lat'] as num).toDouble(),
        destLng: (tripDetails['destination_lng'] as num).toDouble(),
        vehicleType:
            (tripDetails['service_tier_name_snapshot'] as String? ?? 'car').trim().toLowerCase(),
        title: title,
        body: body,
        excludedDriverIds: _broadcastedDriverIds,
      );
      _broadcastedDriverIds.addAll(notifiedDriverIds);

      AppLogger.debug(
        '🔍 SearchingBloc: Broadcast completed for trip $tripId '
        '(${notifiedDriverIds.length} new drivers)',
      );
    } catch (e) {
      AppLogger.error('SearchingBloc: Error broadcasting trip: $e');
    }
  }

  Future<void> _onRebroadcast(
    RebroadcastTripOffers event,
    Emitter<SearchingState> emit,
  ) async {
    if (state is! SearchingInProgress) return;
    await _performBroadcast(event.tripId, event.title, event.body);
  }

  Future<void> _onTick(
    TimerTick event,
    Emitter<SearchingState> emit,
  ) async {
    if (event.remainingSeconds <= 0 && state is SearchingInProgress) {
      _countdownTimer?.cancel();
      _rebroadcastTimer?.cancel();
      await _tripSubscription?.cancel();
      await _offersSubscription?.cancel();
      _tripSubscription = null;
      _offersSubscription = null;

      try {
        final tripId = (state as SearchingInProgress).tripId;

        await withRetry(
          () => SupabaseService.client.rpc(
            'cancel_trip',
            params: {
              'p_trip_id': tripId,
              'p_user_id': SupabaseService.currentUser!.id,
              'p_cancelled_by': 'user',
              'p_cancel_reason': 'timeout',
            },
          ),
          maxAttempts: 2,
          onRetry: (e, attempt) =>
              AppLogger.debug('SearchingBloc: retry cancel #$attempt: $e'),
        );
      } catch (e) {
        AppLogger.debug('SearchingBloc: error cancelling trip on timeout — $e');
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
    AppLogger.debug('🔍 SearchingBloc: Trip status changed to: $status');
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
        AppLogger.debug(
            '🔍 SearchingBloc: Trip is currently searching, waiting for driver...');
        break;
      default:
        AppLogger.debug('🔍 SearchingBloc: Unknown status: $status');
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
      await withRetry(
        () => SupabaseService.client.rpc(
          'cancel_trip',
          params: {
            'p_trip_id': event.tripId,
            'p_user_id': SupabaseService.currentUser!.id,
            'p_cancelled_by': 'user',
            if (event.cancelReason != null)
              'p_cancel_reason': event.cancelReason,
          },
        ),
        maxAttempts: 2,
        onRetry: (e, attempt) =>
            AppLogger.debug('SearchingBloc: retry cancel #$attempt: $e'),
      );
    } catch (e) {
      AppLogger.debug('SearchingBloc: error cancelling trip — $e');
    }
    emit(const SearchingCancelled());
  }

  void _onOffersUpdated(
    OffersUpdated event,
    Emitter<SearchingState> emit,
  ) {
    if (state is SearchingInProgress) {
      emit((state as SearchingInProgress).copyWith(offers: event.offers));
    }
  }

  Future<void> _onAcceptDriverOffer(
    AcceptDriverOffer event,
    Emitter<SearchingState> emit,
  ) async {
    try {
      final result =
          await SupabaseService.client.rpc('user_accept_offer', params: {
        'p_offer_id': event.offerId,
      });
      AppLogger.debug('SearchingBloc: user_accept_offer result: $result');
    } catch (e) {
      AppLogger.debug('SearchingBloc: error accepting driver offer — $e');
    }
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    _rebroadcastTimer?.cancel();
    _tripSubscription?.cancel();
    _offersSubscription?.cancel();
    return super.close();
  }
}
