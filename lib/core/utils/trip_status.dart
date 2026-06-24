enum TripStatus {
  scheduled,
  searching,
  accepted,
  driverArriving,
  inProgress,
  completed,
  cancelled;

  static TripStatus? fromString(String? status) {
    switch (status) {
      case 'scheduled':
        return TripStatus.scheduled;
      case 'searching':
        return TripStatus.searching;
      case 'accepted':
        return TripStatus.accepted;
      case 'driver_arriving':
        return TripStatus.driverArriving;
      case 'in_progress':
        return TripStatus.inProgress;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      default:
        return null;
    }
  }

  String toDbString() {
    switch (this) {
      case TripStatus.scheduled:
        return 'scheduled';
      case TripStatus.searching:
        return 'searching';
      case TripStatus.accepted:
        return 'accepted';
      case TripStatus.driverArriving:
        return 'driver_arriving';
      case TripStatus.inProgress:
        return 'in_progress';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }

  bool canTransitionTo(TripStatus next) {
    switch (this) {
      case TripStatus.scheduled:
        return next == TripStatus.searching || next == TripStatus.cancelled;
      case TripStatus.searching:
        return next == TripStatus.accepted || next == TripStatus.cancelled;
      case TripStatus.accepted:
        return next == TripStatus.driverArriving ||
            next == TripStatus.inProgress ||
            next == TripStatus.cancelled;
      case TripStatus.driverArriving:
        return next == TripStatus.inProgress || next == TripStatus.cancelled;
      case TripStatus.inProgress:
        return next == TripStatus.completed || next == TripStatus.cancelled;
      case TripStatus.completed:
        return false;
      case TripStatus.cancelled:
        return false;
    }
  }

  bool get isTerminal =>
      this == TripStatus.completed || this == TripStatus.cancelled;

  bool get isActive => !isTerminal;

  bool get isCancellable =>
      this == TripStatus.scheduled ||
      this == TripStatus.searching ||
      this == TripStatus.accepted ||
      this == TripStatus.driverArriving;
}
