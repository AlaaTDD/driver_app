import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../features/shared/data/repositories/messages_repository.dart';

class PresenceService {
  final MessagesRepository _repo;
  RealtimeChannel? _channel;
  bool _isTyping = false;

  PresenceService({MessagesRepository? repo})
      : _repo = repo ?? MessagesRepository();

  Future<void> startTracking(String channelKey, {bool isTyping = false}) async {
    await dispose(); // Clean up any existing channel
    _channel = SupabaseService.client.channel(channelKey);
    _isTyping = isTyping;

    // We do NOT subscribe here, we will subscribe in onSync or separately.
    // Actually, to make it safe, we shouldn't track until subscribed.
  }

  void updateTyping(bool isTyping) {
    _isTyping = isTyping;
    if (_channel != null) {
      _repo.trackPresence(_channel!, isTyping: isTyping);
    }
  }

  void onSync(
      Function(Map<String, bool> onlineMap, Map<String, bool> typingMap)
          callback) {
    if (_channel != null) {
      // Setup the sync callback
      _repo.setupPresenceSync(_channel!, callback);

      // NOW subscribe and track
      _channel!.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed && _channel != null) {
          await _repo.trackPresence(_channel!, isTyping: _isTyping);
        }
      });
    }
  }

  Future<void> dispose() async {
    if (_channel != null) {
      await SupabaseService.client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
