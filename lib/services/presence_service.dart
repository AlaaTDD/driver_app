import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../features/shared/presentation/messages/data/messages_repository.dart';

class PresenceService {
  final MessagesRepository _repo = MessagesRepository();
  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;
  bool _isTyping = false;

  Future<void> startTracking(String channelKey, {bool isTyping = false}) async {
    await dispose(); // Clean up any existing channel
    _channel = SupabaseService.client.channel(channelKey);
    await _repo.trackPresence(_channel!, isTyping: isTyping);
    _isTyping = isTyping;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null) {
        _repo.trackPresence(_channel!, isTyping: _isTyping);
      }
    });
  }

  void updateTyping(bool isTyping) {
    _isTyping = isTyping;
    if (_channel != null) {
      _repo.trackPresence(_channel!, isTyping: isTyping);
    }
  }

  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_channel != null) {
      await SupabaseService.client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
