
import 'package:flutter_bloc/flutter_bloc.dart';
import 'meeting_event.dart';
import 'meeting_state.dart';

class MeetingBloc extends Bloc<MeetingEvent, MeetingState> {
  MeetingBloc() : super(const MeetingState()) {
    on<SelectMeetingPoint>(_onSelectMeetingPoint);
    on<UseOriginAsMeetingPoint>(_onUseOriginAsMeetingPoint);
  }

  Future<void> _onSelectMeetingPoint(
    SelectMeetingPoint event,
    Emitter<MeetingState> emit,
  ) async {
    emit(state.copyWith(
      meetingLat: event.lat,
      meetingLng: event.lng,
      meetingAddress: event.address,
    ));
  }

  Future<void> _onUseOriginAsMeetingPoint(
    UseOriginAsMeetingPoint event,
    Emitter<MeetingState> emit,
  ) async {
    emit(state.copyWith(
      meetingLat: null,
      meetingLng: null,
      meetingAddress: null,
    ));
  }
}
