import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../services/supabase_service.dart';
import 'driver_revision_state.dart';

class DriverRevisionCubit extends Cubit<DriverRevisionState> {
  StreamSubscription? _subscription;

  DriverRevisionCubit() : super(const DriverRevisionInitial());

  void subscribe() {
    final driverId = SupabaseService.currentUser?.id;
    if (driverId == null) {
      emit(const DriverRevisionError('errorNotLoggedIn'));
      return;
    }

    emit(const DriverRevisionLoading());
    _subscription?.cancel();
    _subscription = SupabaseService.client
        .from('driver_revision_requests')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .listen(
          (rows) => emit(
            DriverRevisionLoaded(
              requests:
                  rows.map((row) => Map<String, dynamic>.from(row)).toList(),
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'DriverRevisionCubit: subscription failed: $error\n$stackTrace',
            );
            emit(const DriverRevisionError('errorUnexpected'));
          },
        );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
