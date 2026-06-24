---
name: Error Handling & Edge Cases
description: >
  يُفعَّل عند تنفيذ أي feature أو إصلاح أي bug.
  يضمن معالجة شاملة للأخطاء باستخدام AppException الفعلي
  وتغطية كاملة لـ edge cases المحددة لتطبيق Taxi.
priority: HIGH
---

# Error Handling & Edge Cases

> التطبيق لا يتعطّل أبداً. كل خطأ يُمسك، يُسجّل، ويُعرض بشكل لائق.

---

## §1 هرم الأخطاء — exceptions.dart

```dart
// مسار: lib/core/errors/exceptions.dart
AppException (abstract base)
  ├── NetworkException    → default message: 'errorNoInternet'
  ├── AuthException       → 'errorNotLoggedIn', 'errorUserBlocked'
  ├── ValidationException → 'errorPhoneInvalid', 'errorAmountInvalid'
  ├── ServerException     → 'failedCreateTrip', 'failedFetchTrips'
  ├── NotFoundException   → 'errorUserNotFound', 'errorLoadTripDetails'
  ├── PermissionException → default: 'errorPermissionDenied'
  ├── StorageException    → 'errorUploadFailed', 'errorDeleteFailed'
  └── TimeoutException    → default: 'errorRequestTimeout'

// الاستخدام في Repository:
throw const NetworkException();                                // default message
throw const NetworkException('customKey');                     // مفتاح مخصص
throw const ServerException('failedLoadWallet');
throw AuthException('errorUserBlocked', code: 'USER_BLOCKED');
throw const PermissionException();                             // default
throw const TimeoutException();                                // default
```

---

## §2 تدفق الأخطاء — طبقة بطبقة

```
User Action
    ↓
  Widget          ← لا try/catch هنا
    ↓ add(Event)
  BLoC/Cubit      ← try/catch هنا — emit(Error)
    ↓ call
  Repository      ← catch + throw AppException
    ↓ call
  Supabase/API    ← مصدر الخطأ

// قواعد الطبقات:
// Widget: لا try/catch — دائماً يترك للـ BLoC
// BLoC: يمسك كل exception، يُصدر ErrorState
// Repository: يمسك، يُسجّل، يُعيد رمي كـ AppException
// Service: يمسك، يُسجّل، يُعيد رمي أو يُرجع null
```

---

## §3 قالب BLoC الكامل

```dart
// ✅ Template المثالي
Future<void> _onLoadTrips(
  LoadUserTrips event,
  Emitter<TripsState> emit,
) async {
  emit(const TripsLoading());
  try {
    final trips = await _repository.getUserTrips(event.userId);
    if (trips.isEmpty) {
      emit(const TripsEmpty());
    } else {
      emit(TripsLoaded(trips));
    }
  } on NetworkException catch (e) {
    AppLogger.warning('No internet loading trips', tag: 'TripsBloc');
    emit(TripsError(e.message)); // ErrorMapper لو عندك context
  } on AuthException catch (e) {
    AppLogger.error('Auth error in trips', tag: 'TripsBloc', error: e);
    emit(TripsError(e.message));
  } on ServerException catch (e) {
    AppLogger.error('Server error loading trips', tag: 'TripsBloc', error: e);
    emit(TripsError(e.message));
  } on TimeoutException catch (e) {
    AppLogger.warning('Timeout loading trips', tag: 'TripsBloc');
    emit(TripsError(e.message));
  } catch (e, st) {
    AppLogger.error('Unknown error loading trips', tag: 'TripsBloc',
        error: e, stackTrace: st);
    emit(const TripsError('unexpectedError'));
  }
}

// ❌ WRONG — يبتلع الخطأ
Future<void> _bad(...) async {
  try {
    final data = await _repo.get();
    emit(Loaded(data));
  } catch (_) {}  // ❌ المستخدم يرى loading لا نهاية!
}
```

---

## §4 قالب Repository الكامل

```dart
// ✅ Template المثالي
Future<List<TripModel>> getUserTrips(String userId) async {
  try {
    final response = await _client
        .from('trips')
        .select('id, status, fare, pickup_address, destination_address, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));

    return (response as List).map(TripModel.fromJson).toList();
  } on SocketException catch (_) {
    throw const NetworkException();
  } on TimeoutException catch (_) {
    throw const TimeoutException();
  } on PostgrestException catch (e) {
    AppLogger.error('Failed to load trips for $userId', tag: 'TripRepo', error: e);
    if (e.code == '42501') throw const AuthException('errorNotLoggedIn');
    throw ServerException('failedFetchTrips', code: e.code, details: e.message);
  } catch (e, st) {
    AppLogger.error('Unknown error in getUserTrips', tag: 'TripRepo',
        error: e, stackTrace: st);
    rethrow;
  }
}
```

---

## §5 قالب Widget للحالات الثلاث

```dart
// ✅ Template المثالي
BlocBuilder<TripsBloc, TripsState>(
  builder: (context, state) {
    return switch (state) {
      TripsLoading() => const AppLoadingState(),
      TripsError(:final message) => AppErrorState(
          message: message,
          onRetry: () => context.read<TripsBloc>().add(const LoadUserTrips()),
        ),
      TripsEmpty() => AppEmptyState(
          title: l.noTripsYet,
          subtitle: l.startYourFirstTrip,
        ),
      TripsLoaded(:final trips) => _TripsListView(trips: trips),
      _ => const SizedBox.shrink(),
    };
  },
)

// ❌ NEVER:
if (isLoading) return CircularProgressIndicator()   // بلا skeleton
if (hasError) return Text('Error: $error')          // بدائي
if (trips.isEmpty) return Text('No trips')          // بدون تصميم
```

---

## §6 fromJson — Null Safety الصارم

```dart
// ✅ CORRECT
factory TripModel.fromJson(Map<String, dynamic> json) {
  return TripModel(
    id:          json['id'] as String,
    status:      json['status'] as String? ?? 'cancelled',
    fare:        (json['fare'] as num?)?.toDouble() ?? 0.0,
    driverName:  json['driver']?['name'] as String?,
    createdAt:   DateTime.tryParse(json['created_at'] as String? ?? '')
                 ?? DateTime.now(),
    isPaid:      json['is_paid'] as bool? ?? false,
  );
}
// ❌ WRONG — crash guaranteed
factory TripModel.badFromJson(Map<String, dynamic> json) {
  return TripModel(
    id:        json['id'],               // crash if null
    fare:      json['fare'],             // crash if null or int
    createdAt: DateTime.parse(json['created_at']), // crash if null
  );
}
```

---

## §7 StatefulWidget — أنماط خاطئة شائعة في المشروع

```dart
// ❌ Anti-pattern 1: setState بعد dispose
Future<void> _load() async {
  final data = await repo.fetch();
  setState(() => _data = data);  // ❌ crash إذا غادر المستخدم الشاشة
}
// ✅ الحل
Future<void> _load() async {
  try {
    final data = await repo.fetch();
    if (!mounted) return;
    setState(() => _data = data);
  } on AppException catch (e) {
    if (!mounted) return;
    AppToast.error(ErrorMapper.getErrorMessage(context, e.message));
  } catch (e, st) {
    AppLogger.error('Failed', tag: 'Screen', error: e, stackTrace: st);
    if (!mounted) return;
    AppToast.error(ErrorMapper.getErrorMessage(context, 'unexpectedError'));
  }
}

// ❌ Anti-pattern 2: print()
print('data: $data');               // ❌ ممنوع
debugPrint('failed');              // ❌ ممنوع
AppLogger.debug('data: $data', tag: 'Screen'); // ✅

// ❌ Anti-pattern 3: Map<String, dynamic> في States
class TrackingLoaded extends TrackingState {
  final Map<String, dynamic> trip;  // ❌ runtime errors خفية
}
// ✅
class TrackingLoaded extends TrackingState {
  final TripDetailsModel trip;      // ✅ compile-time checked
}
```

---

## §8 Edge Cases المحددة للمشروع

### الرحلات
```
□ Fare = 0 → اعرض "0.00" (مجاناً) لا فراغ
□ Driver = null → "لم يُحدَّد سائق بعد"
□ Pickup/Destination = null → "موقع غير معروف"
□ Trip في inProgress عند إغلاق التطبيق → استئناف عند الفتح
□ 10+ waypoints → UI لا يفيض
□ Coupon discount > fare → fare يصبح 0، لا سالب
□ انقطاع الشبكة أثناء رحلة → آخر موقع معروف للسائق
```

### المحفظة
```
□ Balance = 0 → "0.00" لا فراغ
□ Withdrawal > balance → منع مع رسالة واضحة
□ أرقام كبيرة (999,999.99) → CurrencyFormatter يتعامل معها
```

### المصادقة
```
□ OTP منتهي → "الرمز انتهت صلاحيته، أعد الإرسال"
□ 5 محاولات خاطئة → رسالة rate limit
□ رقم هاتف مع country code → +966، +20
□ مستخدم محجوب → logout + رسالة واضحة
□ Token منتهي → auto-refresh أو إعادة تسجيل الدخول
```

### الخريطة
```
□ بلا GPS → LocationPermissionCta
□ GPS غير دقيق (>100m) → تحذير
□ Route غير موجود → "لا يتوفر مسار"
□ فشل تحميل tiles → معالجة timeout
```

### الكوبونات
```
□ Coupon منتهية الصلاحية → "منتهية" + منع الاستخدام
□ Coupon استُنفدت → "تجاوزت الحد"
□ Discount > fare → fare يصبح صفراً
□ Coupon code → normalize to UPPERCASE
```

---

## §9 Graceful Degradation

```
API تفشل → اعرض cached data + "غير متصل"
صورة تفشل → fallback icon
خريطة تفشل → اعرض العنوان نصاً
ترجمة مفقودة → English fallback
Feature flag مغلق → أخفِ العنصر بنظافة
CellSubscriptionService يفشل → اعرض آخر snapshot معروف
```

---

## §10 Logging Standards

```dart
// ✅ CORRECT — معلومات كافية للتصحيح
AppLogger.error(
  'Failed to load trip $tripId for user $userId',
  tag: 'TripRepo', error: e, stackTrace: st,
);
AppLogger.warning('Retry #$attempt for trip $tripId', tag: 'TripsBloc');
AppLogger.info('Trip $tripId accepted by driver $driverId', tag: 'TripsBloc');
AppLogger.debug('CellService: received ${drivers.length} drivers', tag: 'Cell');

// ❌ WRONG
AppLogger.error('Error', error: e);  // لا سياق
```

---

## §11 Null Safety في Widgets

```dart
// ✅ CORRECT
final address = trip.pickupAddress ?? l.unknownLocation;
final fare = trip.fare?.toStringAsFixed(2) ?? '0.00';
final driverName = trip.driver?.name ?? l.driverNotAssigned;

if (trip.driver != null) _showDriverInfo(trip.driver!);

// ❌ WRONG
final address = trip.pickupAddress!;    // crash if null
```

---

## §12 قائمة تحقق Error Handling

```
□ كل BLoC event handler له try/catch
□ Loading state قبل العمل الـ async
□ Error state في catch مع رسالة للمستخدم
□ Empty state مختلف عن Error state
□ Repository يرمي AppException (لا Exception المجرد)
□ AppLogger.error في كل catch
□ Widget لا تحتوي try/catch
□ fromJson يعالج كل null
□ Subscriptions تُلغى في dispose()
□ mounted check بعد كل await
□ لا silent catch (_) {}
□ لا Map<String, dynamic> في States
```
