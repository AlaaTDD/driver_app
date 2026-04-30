// lib/core/utils/trip_status.dart

/// FIX V01: Proper Trip State Machine enum with validated transitions.
///
/// This replaces raw string status comparisons throughout the app,
/// ensuring only valid state transitions are allowed.
enum TripStatus {
  searching,
  accepted,
  inProgress,
  completed,
  cancelled;

  /// Parse status string from database
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

  /// Convert to database string
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

  /// Check if this status can transition to [next]
  bool canTransitionTo(TripStatus next) {
    switch (this) {
      case TripStatus.searching:
        return next == TripStatus.accepted || next == TripStatus.cancelled;
      case TripStatus.accepted:
        return next == TripStatus.inProgress || next == TripStatus.cancelled;
      case TripStatus.inProgress:
        return next == TripStatus.completed || next == TripStatus.cancelled;
      case TripStatus.completed:
        return false; // Terminal state
      case TripStatus.cancelled:
        return false; // Terminal state
    }
  }

  /// Whether this is a terminal (final) state
  bool get isTerminal => this == TripStatus.completed || this == TripStatus.cancelled;

  /// Whether this is an active (non-terminal) state
  bool get isActive => !isTerminal;

  /// Whether this state can be cancelled
  bool get isCancellable => this == TripStatus.searching || this == TripStatus.accepted;

}
