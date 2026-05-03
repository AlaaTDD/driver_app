
import 'package:equatable/equatable.dart';

abstract class MeetingEvent extends Equatable {
  const MeetingEvent();

  @override
  List<Object?> get props => [];
}

class SelectMeetingPoint extends MeetingEvent {
  final double lat;
  final double lng;
  final String address;

  const SelectMeetingPoint(this.lat, this.lng, this.address);

  @override
  List<Object?> get props => [lat, lng, address];
}

class UseOriginAsMeetingPoint extends MeetingEvent {}
