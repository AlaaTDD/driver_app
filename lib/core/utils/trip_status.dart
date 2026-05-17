enum TripStatus {
  searching,
  accepted,
  inProgress,
  completed,
  cancelled;

  static TripStatus? fromString(String? status) {
    switch (status) {
      case 'searching':
        return TripStatus.searching;
      case 'accepted':
        return TripStatus.accepted;
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
      case TripStatus.searching:
        return 'searching';
      case TripStatus.accepted:
        return 'accepted';
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
      case TripStatus.searching:
        return next == TripStatus.accepted || next == TripStatus.cancelled;
      case TripStatus.accepted:
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
      this == TripStatus.searching || this == TripStatus.accepted;
}
