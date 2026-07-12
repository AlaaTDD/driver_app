import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class HeatmapService {
  HeatmapService._();
  static final HeatmapService instance = HeatmapService._();

  static const double hexRadiusMeters = 300.0;

  /// أقل عدد خلايا يُعتبر تحديثًا صالحًا. أقل من كده بنتجاهل التحديث
  /// ونحتفظ بالـ hexagons القديمة — ده بيمنع الوميض/الاختفاء المؤقت
  /// لما الـ RPC يرجع قائمة فاضية أو ناقصة بسبب latency مؤقت.
  static const int _minViableCells = 1;

  /// معامل smoothing للـ maxCount: نحتفظ بـ 80% من القيمة القديمة
  /// ونأخذ 20% من الجديدة، عشان الألوان متهزّش مع كل تحديث.
  static const double _maxCountSmoothing = 0.8;

  RealtimeChannel? _signalChannel;
  int _channelGeneration = 0;
  bool _isRealtimeSubscribed = false;
  bool _isDisposed = false;

  final _heatmapController = StreamController<List<HeatmapCell>>.broadcast();

  Stream<List<HeatmapCell>> get heatmapUpdates => _heatmapController.stream;

  List<HeatmapCell> _currentCells = [];

  /// maxCount متجانس (smoothed) — مبيتنشأش من الصفر مع كل تحديث،
  /// عشان الـ intensity/الألوان تبقى ثابتة نسبيًا.
  double _smoothedMaxCount = 1.0;

  List<HeatmapCell> get currentCells => List.unmodifiable(_currentCells);

  /// يبدأ التحديث اللحظي: fetch أولي فوري، ثم اشتراك Realtime في جدول
  /// الإشارة الخفيف `heatmap_refresh_signal` (لأن `user_presence` نفسه
  /// UNLOGGED ولا يمكن الاشتراك فيه مباشرة). كل تغيير في `user_presence`
  /// يلمس صف الإشارة عبر Trigger في قاعدة البيانات (مُقيَّد هناك بمرة
  /// واحدة/ثانية على الأكثر عبر شرط WHERE في الـ Trigger نفسه — وليس عبر
  /// أي Timer أو تأخير في هذا الكود). كل حدث UPDATE يصل هنا من Realtime
  /// يُستدعى معه `_fetchHeatmap()` فورًا وبدون أي تأخير من جهة الـ Client.
  Future<void> startRealtimeUpdates() async {
    _isDisposed = false; // Allow restarting after sign-out

    if (_signalChannel != null) {
      if (!_heatmapController.isClosed) {
        _heatmapController.add(List.unmodifiable(_currentCells));
      }
      AppLogger.debug(
          '🔥 Heatmap: Already connected — pushed ${_currentCells.length} cells to new subscriber');
      return;
    }

    await _fetchHeatmap();
    _ensureRealtimeSubscription();
  }

  void _ensureRealtimeSubscription() {
    if (_signalChannel != null) return;
    _subscribeToRealtimeChanges();
  }

  void _subscribeToRealtimeChanges() {
    final generation = ++_channelGeneration;
    final channel = SupabaseService.client.channel('heatmap-refresh-signal');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'heatmap_refresh_signal',
      callback: (payload) {
        if (generation != _channelGeneration) return;
        // استدعاء فوري بدون أي تأخير — الحماية من الحمل الزائد (110K+
        // تحديث/يوم على user_presence) متحققة بالكامل داخل الـ SQL Trigger
        // (signal_heatmap_refresh) الذي يرفض لمس صف الإشارة أكثر من مرة
        // في الثانية، فلا حاجة لأي throttling إضافي هنا.
        unawaited(_fetchHeatmap());
      },
    );

    _signalChannel = channel;
    channel.subscribe((status, [error]) {
      _handleRealtimeStatus(generation, status, error);
    });
  }

  void _handleRealtimeStatus(
    int generation,
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    if (generation != _channelGeneration) return;

    if (status == RealtimeSubscribeStatus.subscribed) {
      if (!_isRealtimeSubscribed) {
        AppLogger.info('Heatmap: Realtime signal subscribed');
        // Snapshot refresh: presence changes between app-start and
        // channel-ready are missed by the initial fetch above.
        // Re-fetch now that the realtime pipe is open so the map reflects
        // anything that changed in that gap.
        unawaited(_fetchHeatmap());
      }
      _isRealtimeSubscribed = true;
      return;
    }

    if (status == RealtimeSubscribeStatus.closed) {
      _isRealtimeSubscribed = false;
      _signalChannel = null;
      AppLogger.info('Heatmap: Realtime signal closed');
      // أعد الاتصال أوتوماتيكياً — بدون ده الـ heatmap بيرجع Static بعد أول قطع اتصال.
      if (generation == _channelGeneration && !_isDisposed) {
        AppLogger.debug('Heatmap: Signal channel closed — scheduling auto-reconnect');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (generation == _channelGeneration &&
              _signalChannel == null &&
              !_isDisposed) {
            AppLogger.info('Heatmap: Auto-reconnecting signal channel...');
            _subscribeToRealtimeChanges();
          }
        });
      }
      return;
    }

    final errorText = error?.toString() ?? '';
    final isAutoReconnectNoise =
        status == RealtimeSubscribeStatus.channelError &&
            (error == null || errorText.contains('code: 1006'));
    if (isAutoReconnectNoise) return;

    _dropRealtimeChannel();
    AppLogger.info('Heatmap: Realtime signal status=$status error=$error');
  }

  void _dropRealtimeChannel() {
    final channel = _signalChannel;
    _signalChannel = null;
    _isRealtimeSubscribed = false;
    if (channel != null) {
      unawaited(SupabaseService.client.removeChannel(channel));
    }
  }

  /// يوقف التحديث اللحظي. افتراضيًا بيحتفظ بالـ hexagons ظاهرة (منع وميض)
  /// إلا لو `clearOnStop: true` (يُستخدم فقط عند الـ dispose الحقيقي).
  void stopRealtimeUpdates({bool clearOnStop = false}) {
    _channelGeneration++; // invalidate any in-flight callbacks/reconnect timers
    _dropRealtimeChannel();
    if (clearOnStop) {
      _currentCells = [];
      _smoothedMaxCount = 1.0;
      if (!_heatmapController.isClosed) {
        _heatmapController.add([]);
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    stopRealtimeUpdates(clearOnStop: true);
    // Do NOT close _heatmapController because this is a Singleton.
    // If user signs out and signs back in, the stream must still be open.
    if (!_heatmapController.isClosed) {
      _heatmapController.add([]); // Emit empty to clear map
    }
  }

  Future<void> _fetchHeatmap() async {
    try {
      final data = await SupabaseService.client.rpc(
        'get_user_presence_heatmap',
        params: {'p_radius_meters': hexRadiusMeters},
      );

      final rows = List<Map<String, dynamic>>.from(data as List? ?? const []);

      // ── تجاهل التحديثات غير الصالحة: لو الـ RPC رجع قائمة فاضية،
      //    نحتفظ بالـ hexagons القديمة بدل ما نفضّي الخريطة.
      //    السبب الأشيع لرجوع [] هو latency/عدم استقرار مؤقت في الاستعلام،
      //    مش إن الداتا فعلاً اختفت.
      if (rows.length < _minViableCells) {
        AppLogger.debug(
            '🔥 Heatmap: Skipped empty/unstable update (${rows.length} rows) — kept ${_currentCells.length} cells');
        return;
      }

      final rawMax = rows.fold<int>(1, (max, row) {
        final count = (row['user_count'] as num?)?.toInt() ?? 0;
        return count > max ? count : max;
      });

      // ── smoothing للـ maxCount: نخلط القيمة القديمة بالجديدة عشان
      //    الألوان متهزّش مع كل تحديث. أول مرة بنبدأ من rawMax.
      _smoothedMaxCount =
          (_smoothedMaxCount * _maxCountSmoothing) + (rawMax * (1 - _maxCountSmoothing));
      // نضمن إنها ما تنزلش تحت قيمة عشان التدرج اللوني يفضل واضح.
      if (_smoothedMaxCount < 1) _smoothedMaxCount = rawMax.toDouble();
      final denom = _smoothedMaxCount > 0 ? _smoothedMaxCount : 1.0;

      // ── تحديث تراكمي: ادمج الجديد مع القديم بدل الاستبدال الكامل.
      //    الخلايا الجديدة بتحل محل القديمة بنفس الـ cellId، والخلايا
      //    اللي اختفت من الاستعلام بتنشال. ده بيخلّي التحديث سلس.
      final newById = <String, HeatmapCell>{};
      for (final row in rows) {
        final count = (row['user_count'] as num?)?.toInt() ?? 0;
        final cellId = row['cell_id'] as String;
        newById[cellId] = HeatmapCell(
          cellId: cellId,
          centerLat: (row['center_lat'] as num).toDouble(),
          centerLng: (row['center_lng'] as num).toDouble(),
          userCount: count,
          intensity: (count / denom).clamp(0.0, 1.0),
          level: _intensityLevel(count),
        );
      }

      _currentCells = newById.values.toList(growable: false);

      _heatmapController.add(List.unmodifiable(_currentCells));
      AppLogger.debug(
          '🔥 Heatmap: Loaded ${_currentCells.length} cells (rawMax=$rawMax, smoothedMax=${_smoothedMaxCount.toStringAsFixed(1)})');
    } catch (e) {
      // عند الخطأ نحتفظ بالقديم — من غير فضّي مفاجئ للخريطة.
      AppLogger.error('Heatmap: Failed to fetch aggregate cells: $e');
    }
  }

  static HeatmapLevel _intensityLevel(int count) {
    if (count >= 10) return HeatmapLevel.high;
    if (count >= 5) return HeatmapLevel.medium;
    return HeatmapLevel.low;
  }
}

class HeatmapCell {
  final String cellId;
  final double centerLat;
  final double centerLng;
  final int userCount;
  final double intensity;
  final HeatmapLevel level;

  const HeatmapCell({
    required this.cellId,
    required this.centerLat,
    required this.centerLng,
    required this.userCount,
    required this.intensity,
    required this.level,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeatmapCell &&
          other.cellId == cellId &&
          other.userCount == userCount;

  @override
  int get hashCode => Object.hash(cellId, userCount);
}

enum HeatmapLevel {
  high,

  medium,

  low,
}
