---
name: Supabase & Database
description: >
  يُفعَّل عند العمل مع Supabase queries، Repository pattern، DB schema،
  RLS policies، Realtime subscriptions، أو أي كود في طبقة البيانات.
  يشمل Flutter app و Next.js dashboard.
priority: HIGH
---

# Supabase & Database

> كل query يجب أن يكون فعّالاً. كل table يجب أن يكون آمناً.
> لا select('*')، لا N+1 queries، لا بدون RLS.

---

## §1 إعداد المشروع

| | Flutter (taxi_app) | Next.js (taxi_web) |
|---|---|---|
| **Client** | `supabase_flutter: ^2.5.0` | `@supabase/ssr` (server) |
| **Auth** | Phone OTP | Email |
| **Realtime** | Channel subscriptions | N/A |
| **Storage** | `R2StorageService` | Direct Supabase Storage |
| **DI** | `RepositoryProvider` في main.dart | N/A |

---

## §2 Query Optimization — قواعد حديدية

### Select الأعمدة المطلوبة فقط
```dart
// ✅ CORRECT
final data = await supabase
    .from('trips')
    .select('id, status, fare, pickup_address, destination_address, created_at')
    .eq('user_id', userId)
    .order('created_at', ascending: false);

// ❌ WRONG — يُحمّل كل البيانات
final data = await supabase.from('trips').select('*').eq('user_id', userId);
```

### Pagination إلزامي للقوائم
```dart
// ✅ CORRECT
const int _pageSize = 20;

Future<List<TripModel>> getTrips(String userId, {int page = 0}) async {
  final offset = page * _pageSize;
  final data = await supabase
      .from('trips')
      .select('id, status, fare, pickup_address, destination_address, created_at')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .range(offset, offset + _pageSize - 1)
      .timeout(const Duration(seconds: 15));
  return (data as List).map((j) => TripModel.fromJson(j)).toList();
}

// ❌ WRONG — تُحمّل آلاف السجلات
final data = await supabase.from('trips').select('*').eq('user_id', userId);
```

### Join لتجنب N+1
```dart
// ✅ CORRECT — join في query واحد
final data = await supabase
    .from('trips')
    .select('''
      id, status, fare, created_at,
      driver:driver_id(id, name, phone, photo_url, rating),
      vehicle:vehicle_id(type, plate_number, color)
    ''')
    .eq('id', tripId)
    .single()
    .timeout(const Duration(seconds: 15));

// ❌ WRONG — 3 queries بدل واحد
final trip = await supabase.from('trips').select().eq('id', tripId).single();
final driver = await supabase.from('profiles').select().eq('id', trip['driver_id']).single();
```

### RPC للعمليات المعقدة والمتكررة
```dart
// ✅ CORRECT — aggregation في قاعدة البيانات
final stats = await supabase.rpc('get_driver_stats', params: {
  'p_driver_id': driverId,
  'p_start_date': startDate.toIso8601String(),
  'p_end_date': endDate.toIso8601String(),
}).timeout(const Duration(seconds: 15));

// ✅ RPCs المعروفة في المشروع:
// - 'get_driver_stats'          → إحصائيات السائق
// - 'accept_trip_atomic'        → قبول رحلة atomically
// - 'verify_driver_atomic'      → تفعيل السائق
// - 'revoke_driver_atomic'      → إيقاف السائق
// - 'get_nearby_drivers'        → السائقون القريبون بالـ geohash
// - وغيرها — تحقق من supabase/migrations/ للمزيد

// ❌ WRONG — aggregation في Flutter
final all = await supabase.from('trips').select('*').eq('driver_id', id);
final sum = all.fold(0.0, (s, t) => s + (t['fare'] as num));
```

### Timeout إلزامي
```dart
// ✅ 15 ثانية على كل query
await supabase.from('trips').select('id, status').eq('user_id', userId)
    .timeout(const Duration(seconds: 15));
```

---

## §3 Repository Pattern — Template كامل

```dart
// ★ كل repository يرث هذا الـ pattern
class TripRepository {
  final SupabaseClient _client;
  TripRepository(this._client);

  Future<List<TripModel>> getUserTrips(String userId, {int page = 0}) async {
    try {
      final data = await _client
          .from('trips')
          .select('id, status, fare, pickup_address, destination_address, created_at, '
              'driver:driver_id(name, photo_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(page * 20, page * 20 + 19)
          .timeout(const Duration(seconds: 15));

      return (data as List).map(TripModel.fromJson).toList();
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const TimeoutException();
    } on PostgrestException catch (e) {
      AppLogger.error('getUserTrips failed', tag: 'TripRepo', error: e);
      if (e.code == '42501') throw const AuthException('errorNotLoggedIn');
      throw ServerException('failedFetchTrips', code: e.code, details: e.message);
    } catch (e, st) {
      AppLogger.error('Unknown error in getUserTrips', tag: 'TripRepo',
          error: e, stackTrace: st);
      rethrow;
    }
  }
}
```

---

## §4 Model fromJson — قواعد حديدية

```dart
factory TripModel.fromJson(Map<String, dynamic> json) {
  return TripModel(
    id: json['id'] as String,                          // ✅ مطلوب
    status: json['status'] as String? ?? 'cancelled',  // ✅ nullable + default
    fare: (json['fare'] as num?)?.toDouble() ?? 0.0,   // ✅ num→double + null
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
               ?? DateTime.now(),                       // ✅ tryParse ليس parse
    driverName: json['driver']?['name'] as String?,    // ✅ nested nullable
    isPaid: json['is_paid'] as bool? ?? false,          // ✅ bool مع default
  );
}

// قواعد fromJson الحديدية:
// ✅ (json['x'] as String?)   — ليس (json['x'] as String)
// ✅ (json['x'] as num?)?.toDouble() — ليس (json['x'] as double)
// ✅ DateTime.tryParse()      — ليس DateTime.parse() المباشر
// ❌ json['x']!              — force unwrap ممنوع مطلقاً
// ❌ json['x'] as T          — بلا null check ممنوع
```

---

## §5 Realtime Subscriptions

```dart
// ✅ CORRECT — subscribe بـ filter محدد
RealtimeChannel? _channel;

void _subscribeToTrip(String tripId) {
  _channel = Supabase.instance.client
      .channel('trip-$tripId')        // ← channel name فريد
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'trips',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: tripId,
        ),
        callback: (payload) => _handleTripUpdate(payload.newRecord),
      )
      .subscribe();
}

@override
void dispose() {
  _channel?.unsubscribe();   // ✅ إلزامي
  super.dispose();
}

// ❌ WRONG — يستقبل كل التحديثات بدون filter
supabase.channel('trips').onPostgresChanges(
  table: 'trips',  // ← كل الجدول!
  callback: (p) => ...,
);
```

### CellSubscriptionService — للسائقين القريبين
```dart
// ✅ الطريقة الصحيحة لتتبع السائقين القريبين (user home screen)
final cellService = CellSubscriptionService.instance;
await cellService.subscribeToCells(userLat, userLng); // ← عند تنقل المستخدم

final sub = cellService.driverUpdates.listen((driversMap) {
  // driversMap: Map<driverId, DriverLocation>
  // تحديث الماركرات على الخريطة
});

// ✅ إلغاء في dispose
await cellService.dispose(); // في screen dispose()
sub.cancel();

// ❌ WRONG — لا تنشئ Supabase channel مباشر لتتبع السائقين
// CellSubscriptionService يدير هذا بنفسه بكفاءة geohash
```

---

## §6 withRetry — للعمليات غير المضمونة

```dart
import 'package:snapix/core/utils/retry_helper.dart';

// ✅ استخدم withRetry للعمليات الحرجة القابلة للتكرار
final data = await withRetry(
  () => _client.from('trips').select('id').eq('id', id).single(),
  maxAttempts: 3,
  initialDelay: const Duration(milliseconds: 500),
  retryIf: (e) => e is SocketException,
  onRetry: (e, n) => AppLogger.warning('Retry #$n: $e', tag: 'Repo'),
);
```

---

## §7 Database Indexes (SQL)

```sql
-- ✅ الـ indexes المعروفة في المشروع
CREATE INDEX idx_trips_user_status   ON trips(user_id, status);
CREATE INDEX idx_trips_driver_status ON trips(driver_id, status);
CREATE INDEX idx_trips_created_at    ON trips(created_at DESC);
CREATE INDEX idx_wallets_user        ON wallets(user_id);
CREATE INDEX idx_transactions_wallet ON wallet_transactions(wallet_id, created_at DESC);
CREATE INDEX idx_drivers_status      ON drivers(status);
CREATE INDEX idx_drivers_geohash     ON driver_locations(geohash6);
-- migrations في: supabase/migrations/
```

---

## §8 API Routes (Next.js Dashboard) — Template

```typescript
// src/app/api/[resource]/[action]/route.ts
import { createClient } from '@/lib/supabase/server';
import { requireAdmin } from '@/lib/supabase/auth-guard';
import { NextResponse } from 'next/server';
import { z } from 'zod';

const schema = z.object({
  id: z.string().uuid(),
  amount: z.number().positive(),
});

export async function POST(request: Request) {
  // 1. Auth guard — ALWAYS أول شيء
  const authResult = await requireAdmin();
  if (authResult instanceof NextResponse) return authResult;

  // 2. Validate input — ALWAYS
  const body = await request.json();
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid input' }, { status: 400 });
  }
  const { id, amount } = parsed.data;

  try {
    const supabase = await createClient();
    const { error } = await supabase.rpc('adjust_wallet_balance', { p_id: id, p_amount: amount });
    if (error) throw error;

    await logAdminAction('wallet_adjust', { id, amount });
    revalidatePath('/dashboard/wallets');
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('wallet adjust error:', error);
    return NextResponse.json({ error: 'Operation failed' }, { status: 500 });
  }
}
```

### API Route Checklist
```
□ requireAdmin() — أول شيء
□ zod schema validation — ثاني شيء
□ try/catch حول كل database calls
□ logAdminAction للعمليات الحساسة
□ revalidatePath بعد mutations
□ HTTP status codes صحيحة (200/400/401/403/500)
□ لا بيانات حساسة في error responses
```

---

## §9 Security

```
□ RLS مفعّل على كل tables
□ Service role key لا يُعرض للـ client
□ كل API routes فيها auth guard
□ Input validation بـ zod على كل API route
□ File uploads: تحقق من type وsize
□ لا passwords/tokens في logs
□ سر Supabase في --dart-define (ليس .env في assets)
```

---

## §10 Status Values الحديدية (DB Strings)

| Feature | القيم |
|---|---|
| Trip | `scheduled`, `searching`, `accepted`, `driver_arriving`, `in_progress`, `completed`, `cancelled` |
| Withdrawal | `pending`, `approved`, `rejected` |
| Coupon | `is_active: true/false` |
| Driver | `pending`, `approved`, `revision`, `revoked` |
| Complaint | `open`, `resolved` |
| Message Ticket | `open`, `closed` |

> ⚠️ **حرج**: `driver_arriving` (بـ underscore) لا `driver-arriving`. `in_progress` لا `in-progress`. `cancelled` لا `canceled`.

---

## §11 أنماط خاطئة معروفة في المشروع

```dart
// ❌ Map<String, dynamic> في BLoC States — موجود في:
// tracking_bloc.dart, searching_state.dart, user_home_state.dart
class TrackingLoaded extends TrackingState {
  final Map<String, dynamic> trip;    // ❌ runtime errors خفية
  final Map<String, dynamic>? driver; // ❌ بلا Equatable صحيح
}

// ✅ البديل الصحيح:
class TrackingLoaded extends TrackingState {
  final TripDetailsModel trip;        // ✅ model مكتوب
  final DriverProfileModel? driver;   // ✅ nullable model
  @override List<Object?> get props => [trip, driver];
}
```

---

## §12 قائمة تحقق Database

```
□ select() محدد بالأعمدة (لا select('*'))
□ Pagination على كل query بقائمة
□ Joins بدل N+1 queries
□ RPC للـ aggregations والعمليات المعقدة
□ Timeout (15s) على كل query
□ try/catch مع AppException types المناسبة
□ Realtime subscriptions بـ filter محدد
□ Subscriptions تُلغى في dispose()
□ fromJson يعالج كل null
□ DB status strings مطابقة للـ Flutter enum strings
□ withRetry للعمليات الحرجة
```
