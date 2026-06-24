---
name: Flutter Performance Optimization
description: >
  يُفعَّل عند بناء أي شاشة أو widget أو list أو map feature.
  يضمن 60fps وأداء مثالي، مكمّل إلزامي لـ taxi-app-architecture.
priority: HIGH
---

# Flutter Performance Optimization

> التطبيق يجب أن يكون فورياً. لا تقطّع، لا rebuilds زائدة، لا memory leaks.

---

## §1 منع Rebuilds غير الضرورية

### const constructors — إلزامي
```dart
// ✅ CORRECT — لا rebuild أبداً
const SizedBox(height: AppSpacing.lg)
const Icon(Icons.check, color: AppColors.success)
const Divider()
const AppSpacing.vMd   // SizedBox(height: 12)

// ❌ WRONG — rebuild في كل مرة
SizedBox(height: 16)   // أضف const!
Icon(Icons.check)       // أضف const!
```

### BlocBuilder مع buildWhen — إلزامي
```dart
// ✅ CORRECT — يُبنى فقط عند تغيير trips
BlocBuilder<TripsBloc, TripsState>(
  buildWhen: (prev, curr) =>
      prev.runtimeType != curr.runtimeType ||
      (curr is TripsLoaded && prev is TripsLoaded && curr.trips != prev.trips),
  builder: (context, state) => TripsListWidget(state: state),
)

// ✅ BlocListener لـ side effects فقط (بلا rebuild)
BlocListener<TripsBloc, TripsState>(
  listenWhen: (prev, curr) => curr is TripsError,
  listener: (context, state) {
    if (state is TripsError) AppToast.error(state.message);
  },
  child: const TripsBody(),
)

// ❌ WRONG — يُبنى على كل state change
BlocBuilder<TripsBloc, TripsState>(
  builder: (context, state) => TripsListWidget(state: state),
)
```

### استخراج Static Parts
```dart
// ✅ CORRECT — الـ static لا يُبنى مع parent
class TripsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const _StaticHeader(),   // ✅ لا يُعاد بناؤه أبداً
      _DynamicContent(),       // ✅ يُبنى فقط عند تغيير State
    ]);
  }
}

// ❌ WRONG — كل شيء يُبنى معاً
Widget build(BuildContext context) {
  return Column(children: [
    Text('Trips', style: context.ts.headlineSm), // يُبنى معك!
    Text('Total: $count'),
  ]);
}
```

> ⚠️ **Widget functions ممنوعة**: لا تستخدم `Widget _buildX() {}`
> ✅ بدلها: `class _XWidget extends StatelessWidget {}`

---

## §2 Lists — أداء إلزامي

```dart
// ✅ CORRECT — lazy building
ListView.builder(
  itemCount: trips.length,
  itemBuilder: (context, i) => SharedAnimatedTripCard(
    key: ValueKey(trips[i].id),   // ← key ضروري للأنيميشن
    trip: trips[i],
  ),
)

// ❌ WRONG — كل العناصر تُبنى مرة واحدة
ListView(
  children: trips.map((t) => SharedAnimatedTripCard(trip: t)).toList(),
)

// ❌ WRONG — أسوأ pattern ممكن
SingleChildScrollView(
  child: Column(
    children: trips.map((t) => TripCard(trip: t)).toList(),
  ),
)
```

---

## §3 Images — أداء إلزامي

```dart
// ✅ AppCachedImage دائماً لصور الشبكة
import 'package:snapix/core/widgets/widgets.dart';
AppCachedImage(
  imageUrl: driver.photoUrl,
  width: 48, height: 48,
  borderRadius: AppRadius.full_,
)

// ❌ WRONG — بلا caching أو error handling
Image.network(driver.photoUrl)

// ✅ ضغط قبل الرفع لـ R2
final compressed = await FlutterImageCompress.compressWithFile(
  file.path, quality: 75, minWidth: 800, minHeight: 800,
);
await r2StorageService.upload(compressed);
```

---

## §4 خريطة Google — أداء إلزامي

### Markers — أنشئها مرة واحدة فقط
```dart
// ✅ CORRECT — أنشئ في initState/BLoC
Set<Marker> _markers = {};

Future<void> _initMarkers(TripDetailsModel trip) async {
  _pickupIcon ??= await AppMapMarkerFactory.createCircleMarker(AppColors.success);
  _destIcon ??= await AppMapMarkerFactory.createCircleMarker(AppColors.error);
  _markers = {
    if (_pickupIcon != null && trip.pickupLat != null)
      Marker(
        markerId: const MarkerId('pickup'),
        position: tripPoint(trip.pickupLat, trip.pickupLng)!,
        icon: _pickupIcon!,
      ),
  };
  if (mounted) setState(() {});
}

// ❌ WRONG — تُنشأ في كل build()
Widget build(BuildContext context) {
  return AppGoogleMap(
    markers: {Marker(markerId: MarkerId('pickup'), ...)}  // في كل frame!
  );
}
```

### Camera — animate لا move
```dart
// ✅ سلس
_mapController.controller.animateCamera(
  CameraUpdate.newLatLngBounds(bounds, 80),
);

// ❌ مقلق للمستخدم
_mapController.controller.moveCamera(
  CameraUpdate.newLatLngBounds(bounds, 80),
);
```

### Polylines — بسّط النقاط
```dart
// ✅ simplify قبل الرسم
final simplified = _simplifyPolyline(routePoints, tolerance: 0.00005);
setState(() => _polylines = {Polyline(points: simplified, ...)});

// ❌ آلاف النقاط تُبطّئ rendering
setState(() => _polylines = {Polyline(points: rawRoutePoints, ...)});
```

### بنية Stack مع الخريطة
```dart
// ✅ CORRECT — الخريطة مستقلة عن الـ BLoC
Widget build(BuildContext ctx) {
  return Stack(children: [
    const _MapLayer(),                                    // ✅ const — لا rebuild
    BlocBuilder<TrackingBloc, TrackingState>(
      buildWhen: (p, c) => c is TrackingLoaded,           // ✅ فلتر صارم
      builder: (_, state) => _TrackingPanel(state: state),
    ),
    const _ActionButtons(),                               // ✅ const
  ]);
}

// ❌ WRONG — الخريطة داخل BlocBuilder — تُعاد بناؤها في كل state!
BlocBuilder<TrackingBloc, TrackingState>(
  builder: (ctx, state) => Stack(children: [
    GoogleMap(...), // أبطأ شيء!
  ])
)
```

---

## §5 Memory Management

```dart
// ✅ إلغاء كل شيء في dispose()
class _TripTrackingState extends State<TripTrackingScreen> {
  StreamSubscription? _tripSub;
  StreamSubscription? _locationSub;
  RealtimeChannel? _channel;
  Timer? _refreshTimer;

  @override
  void dispose() {
    _tripSub?.cancel();
    _locationSub?.cancel();
    _channel?.unsubscribe();
    _refreshTimer?.cancel();
    CellSubscriptionService.instance.dispose(); // ✅ إذا استخدمته
    super.dispose();
  }
}
```

### Debounce للبحث
```dart
// ✅ 300ms debounce
Timer? _debounce;
void _onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 300), () {
    if (mounted) context.read<SearchBloc>().add(SearchQuery(query));
  });
}

// ❌ WRONG — event لكل حرف
```

---

## §6 الشاشات الكبيرة — استخراج إلزامي

```
الملفات الحالية المخالفة (تحتاج استخراج widgets في أي تعديل مستقبلي):
- tracking_screen.dart          ~1400 سطر
- trip_details_screen.dart      ~1800 سطر (سائق + مستخدم)
- location_selection_screen.dart ~2500 سطر
- complaints_screen.dart         ~700 سطر
- driver_home_screen.dart        ~800 سطر
```

```dart
// ❌ WRONG — كل شيء داخل build() واحد
Widget build(BuildContext ctx) {
  return BlocBuilder<TrackingBloc, TrackingState>(
    builder: (ctx, state) => Stack(children: [
      GoogleMap(...),    // rebuild عند كل state change
      _buildPanel(state),
      _buildButtons(),
    ]),
  );
}

// ✅ CORRECT — مكونات مستقلة
Widget build(BuildContext ctx) {
  return Stack(children: [
    const _MapLayer(),              // ✅ لا يُعاد بناؤه
    BlocBuilder<TrackingBloc, TrackingState>(
      buildWhen: (p, c) => c is TrackingLoaded,
      builder: (_, state) => _TrackingPanel(state: state),
    ),
    const _ActionButtons(),         // ✅ مستقل
  ]);
}
```

---

## §7 Startup + Initialization

```dart
// ✅ Lazy Initialization
late final LocationService _locationService = LocationService();

// main.dart يجب فقط:
// 1. WidgetsFlutterBinding.ensureInitialized()
// 2. Supabase.initialize()
// 3. Firebase.initializeApp() + AppLogger.initCrashlytics()
// 4. FCMService().initialize()
// 5. ConnectivityService().init()
// 6. AppConfigRepository loading (في background — unawaited)
// 7. SharedPreferences → theme/language
// 8. runApp()
// لا heavy computation، لا pre-loading data في main.dart
```

---

## §8 قائمة تحقق الأداء

```
□ const constructors في كل مكان ممكن
□ ListView.builder للقوائم (لا Column/ListView مع children)
□ BlocBuilder لديه buildWhen filter
□ Markers تُنشأ في initState لا في build()
□ Camera animate لا move
□ Polylines مُبسَّطة
□ Subscriptions تُلغى في dispose()
□ mounted check بعد كل await
□ الصور مع AppCachedImage
□ Debounce للبحث
□ Static widgets مستخرجة من الـ build الديناميكي
□ Keys للـ animated lists
□ شاشات > 400 سطر → استخراج classes مستقلة (ليس functions)
□ BlocBuilder داخل Stack → فلتر buildWhen صارم
□ لا Widget functions في build — استخدم classes
```
