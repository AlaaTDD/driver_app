
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/supabase_service.dart';
import 'ride_offer_event.dart';
import 'ride_offer_state.dart';

class RideOfferBloc extends Bloc<RideOfferEvent, RideOfferState> {
  Timer? _countdownTimer;

  RideOfferBloc() : super(const RideOfferState()) {
    on<RideOfferReceived>(_onOfferReceived);
    on<RideOfferAccepted>(_onOfferAccepted);
    on<RideOfferDeclined>(_onOfferDeclined);
    on<RideOfferTimerTick>(_onTimerTick);
    on<RideOfferDismissed>(_onDismissed);
  }

  void _onOfferReceived(
    RideOfferReceived event,
    Emitter<RideOfferState> emit,
  ) {
    _countdownTimer?.cancel();
    emit(state.copyWith(
      status: RideOfferStatus.incoming,
      currentOffer: event.offer,
      remainingSeconds: 30,
      clearError: true,
    ));
    _startCountdown(emit);
  }

  Future<void> _onOfferAccepted(
    RideOfferAccepted event,
    Emitter<RideOfferState> emit,
  ) async {
    _countdownTimer?.cancel();
    emit(state.copyWith(status: RideOfferStatus.accepted));

    try {
      final result = await SupabaseService.client.rpc('driver_accept_trip', params: {
        'p_trip_id': state.currentOffer?.id ?? event.offerId,
      });
      
      if (result == null || result['success'] != true) {
        emit(state.copyWith(
          status: RideOfferStatus.error,
          errorMessage: result?['error'] ?? 'Failed to accept offer',
        ));
        return;
      }

      debugPrint('RideOfferBloc: Offer ${event.offerId} accepted');
    } catch (e) {
      debugPrint('RideOfferBloc: Accept failed — $e');
      emit(state.copyWith(
        status: RideOfferStatus.error,
        errorMessage: 'Failed to accept offer',
      ));
    }
  }

  Future<void> _onOfferDeclined(
    RideOfferDeclined event,
    Emitter<RideOfferState> emit,
  ) async {
    _countdownTimer?.cancel();
    emit(state.copyWith(
      status: RideOfferStatus.declined,
      clearOffer: true,
    ));

    try {
      await SupabaseService.client
          .from('trip_offers')
          .update({'status': 'declined'})
          .eq('id', event.offerId);
    } catch (e) {
      debugPrint('RideOfferBloc: Decline failed — $e');
    }
  }

  void _onTimerTick(
    RideOfferTimerTick event,
    Emitter<RideOfferState> emit,
  ) {
    if (event.remainingSeconds <= 0) {
      _countdownTimer?.cancel();
      emit(state.copyWith(
        status: RideOfferStatus.expired,
        remainingSeconds: 0,
        clearOffer: true,
      ));
      return;
    }
    emit(state.copyWith(remainingSeconds: event.remainingSeconds));
  }

  void _onDismissed(
    RideOfferDismissed event,
    Emitter<RideOfferState> emit,
  ) {
    _countdownTimer?.cancel();
    emit(const RideOfferState());
  }

  void _startCountdown(Emitter<RideOfferState> emit) {
    _countdownTimer?.cancel(); 
    int seconds = 30;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds--;
      if (!isClosed) {
        add(RideOfferTimerTick(seconds));
      }
      if (seconds <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }
}
