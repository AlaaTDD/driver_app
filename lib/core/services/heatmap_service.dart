import 'dart:async';
import 'supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class HeatmapService {
  HeatmapService._();
  static final HeatmapService instance = HeatmapService._();

  static const double hexRadiusMeters = 300.0;
  static const Duration _refreshInterval = Duration(seconds: 10);

  /// أقل عدد خلايا يُعتبر تحديثًا صالحًا. أقل من كده بنتجاهل التحديث
  /// ونحتفظ بالـ hexagons القديمة — ده بيمنع الوميض/الاختفاء المؤقت
  /// لما الـ RPC يرجع قائمة فاضية أو ناقصة بسبب latency مؤقت.
  static const int _minViableCells = 1;

  /// معامل smoothing للـ maxCount: نحتفظ بـ 80% من القيمة القديمة
  /// ونأخذ 20% من الجديدة، عشان الألوان متهزّش مع كل تحديث.
  static const double _maxCountSmoothing = 0.8;

  Timer? _refreshTimer;
  bool _isDisposed = false;

  final _heatmapController = StreamController<List<HeatmapCell>>.broadcast();

  Stream<List<HeatmapCell>> get heatmapUpdates => _heatmapController.stream;

  List<HeatmapCell> _currentCells = [];

  /// maxCount متجانس (smoothed) — مبيتنشأش من الصفر مع كل تحديث،
  /// عشان الـ intensity/الألوان تبقى ثابتة نسبيًا.
  double _smoothedMaxCount = 1.0;

  List<HeatmapCell> get currentCells => List.unmodifiable(_currentCells);

  Future<void> startRealtimeUpdates() async {
    _isDisposed = false; // Allow restarting after sign-out

    if (_refreshTimer != null) {
      if (!_heatmapController.isClosed) {
        _heatmapController.add(List.unmodifiable(_currentCells));
      }
      AppLogger.debug(
          '🔥 Heatmap: Already connected — pushed ${_currentCells.length} cells to new subscriber');
      return;
    }

    await _fetchHeatmap();
    _refreshTimer ??= Timer.periodic(
      _refreshInterval,
      (_) => unawaited(_fetchHeatmap()),
    );
  }

  /// يوقف التحديث الدوري. افتراضيًا بيحتفظ بالـ hexagons ظاهرة (منع وميض)
  /// إلا لو `clearOnStop: true` (يُستخدم فقط عند الـ dispose الحقيقي).
  void stopRealtimeUpdates({bool clearOnStop = false}) {
    _refreshTimer?.cancel();
    _refreshTimer = null;
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
