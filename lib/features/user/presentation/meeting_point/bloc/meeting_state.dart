
import 'package:equatable/equatable.dart';

class MeetingState extends Equatable {
  final double? meetingLat;
  final double? meetingLng;
  final String? meetingAddress;

  const MeetingState({
    this.meetingLat,
    this.meetingLng,
    this.meetingAddress,
  });

  MeetingState copyWith({
    double? meetingLat,
    double? meetingLng,
    String? meetingAddress,
  }) {
    return MeetingState(
      meetingLat: meetingLat ?? this.meetingLat,
      meetingLng: meetingLng ?? this.meetingLng,
      meetingAddress: meetingAddress ?? this.meetingAddress,
    );
  }

  @override
  List<Object?> get props => [meetingLat, meetingLng, meetingAddress];
}
