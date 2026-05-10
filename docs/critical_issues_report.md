# 🚨 تقرير المشاكل الحرجة الشامل
## تحليل عميق: Logic · UI · Database · Security · Architecture
**التطبيق:** Taxi App (Flutter + Supabase + Firebase)  
**تاريخ التحليل:** 2026-05-10  
**إجمالي المشاكل المكتشفة: 108 مشكلة حرجة**

---

## 📋 فهرس التصنيفات

| التصنيف | عدد المشاكل | درجة الخطورة |
|--------|------------|------------|
| 🔴 أمن وتسريب بيانات | 20 | حرجة جداً |
| 🟠 قاعدة البيانات والـ Schema | 22 | حرجة |
| 🟡 Logic الأعمال | 21 | حرجة |
| 🔵 معمارية الكود | 18 | عالية |
| 🟣 واجهة المستخدم | 12 | متوسطة-عالية |
| ⚫ تشغيل وإنتاج | 15 | حرجة |

---

## 🔴 القسم الأول: الأمن وتسريب البيانات (Critical Security)

### [SEC-01] 🚨 Firebase API Keys مكشوفة في الكود
**الملف:** `lib/firebase_options.dart`  
**الخطورة:** حرجة جداً

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyCRw-PPmQ_7iG6T4cRjTa5kTY7T8BBkPzI',  // مكشوف!
  appId: '1:741233752146:android:...',
  projectId: 'arai-449ca',
);
```

Firebase API Keys موجودة hardcoded في الكود، ومعها `projectId` و`storageBucket`. أي شخص يفتح APK يقدر يعمل decompile ويجيب كل بيانات Firebase. هذا يسمح باستغلال Firebase Storage وFirebase Auth في مشاريع أخرى.

**الحل:** استخدم `google-services.json` + CI/CD secrets، ولا تضع أي key في الكود مباشرة.

---

### [SEC-02] 🚨 R2 Secret Key مكشوف في تطبيق المحمول
**الملف:** `lib/core/constants/env_constants.dart` + `lib/services/r2_storage_service.dart`  
**الخطورة:** حرجة جداً

```dart
static String get r2SecretKey => dotenv.env['R2_SECRET_KEY']!;
// ويُستخدم في:
_minio = Minio(secretKey: EnvConstants.r2SecretKey, ...);
```

الـ `.env` file يُشحن مع التطبيق. أي شخص يعمل unzip للـ APK/IPA يجد الـ R2 secret key كاملاً ويقدر يرفع/يحذف/يقرأ أي ملف في Cloudflare R2 bucket بدون قيود.

**الحل:** رفع الملفات يتم عبر Supabase Edge Function أو Backend API، مش من الكلاينت مباشرة.

---

### [SEC-03] 🚨 OpenRouter/AI API Key في تطبيق المحمول
**الملف:** `lib/core/constants/env_constants.dart`  
**الخطورة:** حرجة جداً

```dart
static String get openRouterApiKey => dotenv.env['OPENAI_API_KEY']!;
```

أي شخص يعمل decompile للتطبيق يجد AI API key ويقدر يستخدمه بشكل مجاني على حساب المشروع. الفاتورة ممكن تكون ضخمة جداً.

**الحل:** طلبات AI تمر عبر Supabase Edge Function فقط، والـ key يكون في environment variables الـ server-side.

---

### [SEC-04] 🔴 جميع المستخدمين يشوفوا بيانات بعضهم في `users`
**الجدول:** `users`  
**الـ Policy:** `"Authenticated users can see basic user info"` → `using_expression: true`

أي مستخدم authenticated يقدر يقرأ **جميع** rows في جدول `users`، بما فيها:
- أرقام التليفون (`phone`)
- سبب الحظر (`blocked_reason`)
- وقت الحظر (`blocked_at`)
- `fcm_token` (خطير: يسمح بإرسال push notifications مزيفة)
- بيانات شخصية كاملة لكل مستخدم

**الحل:** 
```sql
-- بدّل الـ policy لـ:
using_expression: "(auth.uid() = id) OR is_admin_user()"
-- وأنشئ view منفصلة للبيانات العامة فقط
```

---

### [SEC-05] 🔴 FCM Token مكشوف لجميع المستخدمين
**الجدول:** `users` (ناتج من [SEC-04])  
**الخطورة:** حرجة

`fcm_token` مخزن في جدول `users` وبسبب policy "Authenticated users can see basic user info" (using: `true`)، أي مستخدم يقدر يقرأ FCM token لأي شخص آخر ويبعتله push notifications خارج التطبيق.

---

### [SEC-06] 🔴 `driver_locations` مكشوفة لجميع المستخدمين
**الجدول:** `driver_locations`  
**الـ Policy:** `"Authenticated can read driver locations"` → `using_expression: true`

أي مستخدم authenticated يقدر يشوف location كل السواقين في الوقت الحقيقي بدون قيود. هذا يُعرّض خصوصية السواق للخطر ويسمح بتتبع حركتهم.

---

### [SEC-07] 🔴 `user_presence` مكشوفة لجميع المستخدمين
**الجدول:** `user_presence`  
**الـ Policy:** `"Authenticated can read presence"` → `using_expression: true`

أي مستخدم يعرف متى غيره online/offline ومكانه الجغرافي في الوقت الحقيقي. مشكلة خصوصية حرجة.

---

### [SEC-08] 🔴 `ratings` مكشوفة للعموم (anon)
**الجدول:** `ratings`  
**الـ Policy:** `"Public can read ratings"` → `roles: ["public"]`

الـ `public` role يعني حتى غير المسجلين يقدروا يقروا جميع التقييمات. البيانات تشمل `user_id` و`driver_id` وهذا يكشف علاقات المستخدمين.

---

### [SEC-09] 🔴 `coupons` مكشوفة للعموم (anon)
**الجدول:** `coupons`  
**الـ Policy:** `"Public can read coupons"` → `roles: ["public"]`

أي شخص حتى لو مش مسجل يقدر يشوف ويجرب جميع الكوبونات المتاحة، مما يسهل استغلال أو استنزاف الكوبونات.

---

### [SEC-10] 🔴 `drivers_profile` يكشف بيانات حساسة
**الجدول:** `drivers_profile`  
**الـ Policy:** `"Authenticated users view available drivers"` → using: `((is_verified = true) AND (is_available = true))`

هذه الـ policy تسمح لأي مستخدم authenticated برؤية **جميع بيانات** السواق المتاحين، بما فيها:
- `national_id` (رقم بطاقة الهوية)
- `license_number` (رقم الرخصة)
- `national_id_image_url` (صورة البطاقة)
- `license_image_url` (صورة الرخصة)
- `criminal_record_url` (صورة صحيفة السوابق)

**الحل:** أنشئ view منفصلة للبيانات العامة فقط (الاسم، السيارة، التقييم).

---

### [SEC-11] 🔴 Client-Side Trip Broadcasting - ثغرة أمنية حرجة
**الملف:** `lib/services/trip_broadcast_service.dart`  
**الخطورة:** حرجة جداً

منطق إيجاد السواقين وإرسال عروض الرحلات يعمل من الكلاينت مباشرة:

```dart
// هذا الكود يعمل على موبايل المستخدم
Future<List<String>> findNearbyDrivers(...) async {
  final results = await SupabaseService.client
      .from('drivers_profile')
      .select('id, geohash, geohash5, vehicle_type')
      .eq('is_available', true)
      ...
}
// ثم يعمل insert مباشر في trip_offers
await SupabaseService.client.from('trip_offers').insert(offers);
```

مستخدم خبيث يقدر:
1. يعدّل الكود ويبعت offers لسواقين محددين دون الـ geohash logic
2. يبعت عروض لنفسه إذا كان عنده account سائق
3. يستهدف سواق معينين ويمنعهم من استقبال رحلات

**الحل:** كل هذا المنطق يجب أن يكون في Supabase Edge Function أو Database trigger.

---

### [SEC-12] 🔴 `expire_trip_offers` Trigger بـ SECURITY INVOKER
**الدالة:** `expire_trip_offers`  
```json
"security": "INVOKER"  // خطأ! كل triggers التانية DEFINER
```

هذا الـ trigger يعمل بصلاحيات المستخدم الحالي مش بصلاحيات `postgres`. لو المستخدم ما عندوش إذن كافي، الـ trigger هيفشل صامتاً وعروض الرحلات المنتهية هتفضل.

---

### [SEC-13] 🟡 `cleanup_stuck_trips()` يُستدعى من الكلاينت عند الـ startup
**الملف:** `lib/main.dart`

```dart
await _cleanupStaleTrips(); // يعمل قبل login
```

هذا الـ RPC يُستدعى كـ anon user قبل أي authentication. لو في bug في الـ function، ممكن تحذف بيانات غلط.

---

### [SEC-14] 🔴 `is_admin_user()` Recursive Query خطر
**الدالة:** `is_admin_user()` تقرأ من جدول `users` وهذه الدالة تُستخدم في RLS policies على نفس الجدول `users`. في PostgreSQL، لو مش متحسب كويس، ممكن يحصل recursive RLS evaluation ويتخطى الـ security.

---

### [SEC-15] 🟡 `messages` - دبل INSERT Policies تتعارض
**الجدول:** `messages`  
يوجد **سياستان** لـ INSERT في نفس الوقت:
- `"Users can send messages"` - بـ conditions معقدة
- `"Users can send trip messages"` - بـ EXISTS على trips فقط

كلاهما permissive، يعني يكفي واحدة منهم تتحقق. المستخدم يقدر يتجاوز الـ policy الأكثر تقييداً ويستخدم الأبسط.

---

### [SEC-16] 🟡 `drivers_profile` DELETE بدون تحقق من is_verified
**الـ Policy:** `"Drivers can delete own profile"` → `using: "(auth.uid() = id) AND (is_verified = false)"`

سائق unverified يقدر يمسح profile بعد تقديم بياناته، مما يسمح بتجاوز process التحقق عن طريق التسجيل مرات كتير.

---

### [SEC-17] 🟡 `admin_logs` فارغ (0 rows) رغم العمليات المتعددة
**الجدول:** `admin_logs` → `rows.live: 0`

جدول الـ audit log للأدمن فارغ تماماً رغم وجود عمليات admin. يعني إما `log_admin_action()` مش بتُستدعى، أو الـ INSERT بيفشل. هذا يعني **لا يوجد audit trail** لأي عملية admin.

---

### [SEC-18] 🟡 `notifications` فارغة (0 rows) رغم إرسال FCM
**الجدول:** `notifications` → `rows.live: 0`

التطبيق يرسل FCM notifications لكن لا يحفظها في DB. لو الـ FCM فشل (offline device)، الإشعار يضيع تماماً بدون أي fallback.

---

### [SEC-19] 🟡 Chatbot AI Config يُرسل من الكلاينت
**الملف:** `lib/features/shared/data/repositories/chatbot_repository.dart`

```dart
body: {
  'model': EnvConstants.aiModel,          // من .env
  'max_tokens': EnvConstants.aiMaxTokens,  // من .env
  'temperature': EnvConstants.aiTemperature, // من .env
},
```

مستخدم خبيث يقدر يعدّل هذه القيم ويستخدم models أغلى تكلفة أو يرفع الـ max_tokens لاستنزاف الـ API credits.

---

### [SEC-20] 🟡 لا يوجد Rate Limiting على أي operation في الكلاينت
لا يوجد rate limiting على:
- إرسال رسائل support
- طلب عروض الرحلات
- تحديث location
- استدعاء chatbot

مستخدم خبيث يقدر يعمل spam ويستنزف الموارد أو يملأ DB بـ junk data.

---

## 🟠 القسم الثاني: قاعدة البيانات والـ Schema

### [DB-01] 🚨 `user_presence` Bloat 85.71% - أزمة أداء حرجة
**الجدول:** `user_presence`  
```
updates: 97,403  hot_updates: 91,246  live: 1  dead: 6
bloat: 85.71%
```

الجدول فيه 97,403 update لصف واحد فقط. الـ HOT updates نجح في 91K حالة لكن الـ bloat وصل 85.71%. الـ autovacuum لسه مش لحقه. في production مع عدد كبير من المستخدمين، هذا سيسبب:
- انهيار performance لجميع queries
- زيادة حجم الـ database بشكل غير معقول

**الحل الفوري:**
```sql
VACUUM ANALYZE user_presence;
-- على المدى البعيد: UNLOGGED TABLE أو Redis
```

---

### [DB-02] 🔴 `drivers_profile` Bloat 75% مع 1167 Update
**الجدول:** `drivers_profile`

```
inserts: 10  updates: 1167  live: 3  dead: 9
bloat: 75%
```

جدول السواقين بيتحدث بكثافة ومفيش vacuum manual. عند growth بسيط هيتدهور بسرعة.

---

### [DB-03] 🔴 `users` Bloat 61.11% مع HOT Updates 100%
**الجدول:** `users`

```
inserts: 32  updates: 56  hot_updates: 56  live: 7  dead: 11
bloat: 61.11%
```

100% من الـ updates هي HOT (مميز) لكن الـ bloat عالي جداً نسبة لعدد الـ rows.

---

### [DB-04] 🔴 66.67% من السواقين `geohash` = NULL
**الجدول:** `drivers_profile`  
```
WARNING: 66.67% of drivers have NULL geohash and geohash5.
get_nearby_drivers() searches by geohash prefix — only 1 in 3 drivers will be found.
```

الـ `findNearbyDrivers` و`get_nearby_drivers()` تبحث بالـ geohash5، لكن ثلثين السواقين geohash5 = NULL. هذا يعني:
- المستخدم يطلب سيارة ولا يجد سواقين رغم وجودهم
- الـ heatmap يُظهر بيانات ناقصة

---

### [DB-05] 🔴 `trips` جدول فيه أعمدة مكررة (Duplicate Columns)
**الجدول:** `trips`

```
pickup_address (NOT NULL, position 4) = origin_address (nullable, position 24)
destination_address (NOT NULL, position 7) = dest_address (nullable, position 25)
```

4 أعمدة تحمل نفس البيانات. هذا يضيف confusion ويزيد حجم كل row بدون فائدة.

---

### [DB-06] 🔴 `trips` يحتوي 9 أعمدة 100% NULL
**الجدول:** `trips`

الأعمدة التالية كلها `NULL` في جميع الـ 79 row:
- `payment_method`
- `meeting_lat`, `meeting_lng`, `meeting_address`
- `accepted_at`, `started_at`
- `user_rating_to_driver`, `driver_rating_to_user`
- `cancel_reason`

هذه ميزات مصممة في DB لكن غير مكتملة في Flutter.

---

### [DB-07] 🔴 `trips` Bloat 37.8% مع 104 Insert و152 Update
**الجدول:** `trips`

```
dead: 48  live: 79  hot_updates: 33 (22% فقط)
bloat: 37.80%
```

الـ fillfactor = 85 لكن HOT updates نسبتها منخفضة جداً (22%). يعني الـ tuning مش كافي.

---

### [DB-08] 🔴 `wallet_transactions` - خلط Driver و User Wallets
**الجدول:** `wallet_transactions`  
**الـ RLS Policy:**
```json
"using_expression": "(auth.uid() = wallet_id)"
```

`wallet_id` في هذا الجدول يُشير لـ `driver_wallets.id` أو `user_wallets.id`، وكلاهما UUID. لكن الـ PK لكل من هذين الجدولين هو `users.id`. الـ RLS تعمل `auth.uid() = wallet_id` وهذا صح، لكن الإشكالية أن Driver wallet و User wallet لهم نفس الـ UUID (user.id)، مما يعني:
- سائق يقدر يشوف transactions المستخدمين والعكس إذا كانت عندهم نفس الـ UUID

---

### [DB-09] 🟡 `pricing_config` بدون FK لـ `vehicle_types`
**الجدول:** `pricing_config`

```
"Standalone pricing config table (zero FK relationships)"
```

جدولان للأسعار بدون ربط: `pricing_config` و`vehicle_types` (اللي فيه columns للأسعار). أسعار في الاثنين ممكن تكون متعارضة.

---

### [DB-10] 🟡 `driver_wallets` و `user_wallets` - No Default UUID
**الجدولان:** `driver_wallets`, `user_wallets`  
```json
"default": null  // مش "gen_random_uuid()"
```

الـ ID في الـ wallets مفيش default value. يعني لو الـ trigger فشل في إنشاء الـ wallet، أي insert يدوي بدون تحديد ID سيفشل بـ NOT NULL violation.

---

### [DB-11] 🔴 Indexes غير مُستخدمة (Dead Weight)
**الفهارس الغير مُستخدمة:**
```
idx_notifications_user_created       → scans: 0 (UNUSED)
idx_wallet_txns_wallet_created       → scans: 0 (UNUSED)
idx_withdrawal_driver_created        → scans: 0 (UNUSED)
unique_idempotency (withdrawal)      → scans: 0 (UNUSED)
wallet_transactions_pkey             → scans: 0 (UNUSED)
uq_coupon_usages_trip               → scans: 0 (UNUSED)
coupons_code_key                    → scans: 0 (UNUSED)
uq_ratings_trip_user               → scans: 0 (UNUSED)
uq_trip_offers_trip_driver         → scans: 0 (UNUSED)
```

9 indexes غير مستخدمة تأكل disk space وتبطئ كل INSERT/UPDATE بدون فائدة.

---

### [DB-12] 🟡 عدم وجود Index مركّب على `trips (user_id, status)`
يوجد `idx_trips_driver_status` لكن لا يوجد مكافئه للـ user. كل query تبحث عن رحلات مستخدم بحالة معينة تعمل seq scan على `idx_trips_user_id` ثم تفلتر.

---

### [DB-13] 🟡 `vehicle_types` Bloat 73.33%
```
inserts: 9  updates: 14  live: 4  dead: 11
bloat: 73.33%
```

جدول صغير لكن bloat عالي جداً. يحتاج VACUUM.

---

### [DB-14] 🟡 `trip_offers` - HOT Updates = 0%
```
inserts: 65  updates: 68  hot_updates: 0
```

0% HOT updates في جدول يتحدث 68 مرة. يعني كل update ينشئ row جديد في الـ heap. هذا بسبب أن الأعمدة المُعدَّلة عليها indexes.

---

### [DB-15] 🟡 `driver_locations` Bloat 60% مع fillfactor 70
```
updates: 438  hot_updates: 0  dead: 3  live: 2
bloat: 60%
```

نفس مشكلة HOT updates = 0 مع جدول location يتحدث بكثافة عالية.

---

### [DB-16] 🟡 عدم وجود Partitioning على `trips` و`messages`
لا يوجد partitioning بالتاريخ على الجداول الأكثر نمواً. عند آلاف الرحلات، كل query ستصبح full scan.

---

### [DB-17] 🟡 `trg_cleanup_orphan_offers` يعمل على كل UPDATE في `trips`
**الـ Trigger:** `trg_cleanup_orphan_offers` ← `cleanup_orphan_trip_offers()`

يُشتغل على **كل** UPDATE في trips بدون condition. حتى لو حدّثت `updated_at` فقط، الـ trigger يعمل. هذا يُبطئ كل update.

---

### [DB-18] 🟡 `trg_validate_trip_price` يعمل على كل INSERT و UPDATE
**الـ Trigger:** `trg_validate_trip_price` ← `validate_trip_price_on_insert()`

يعمل على كل INSERT وUPDATE حتى لو `price` لم يتغير.

---

### [DB-19] 🟡 `trips` - 5 Triggers على UPDATE في نفس الجدول
الجدول `trips` عليه 5 triggers تعمل على UPDATE:
- `trg_cleanup_orphan_offers`
- `trg_expire_trip_offers`
- `trg_trip_status_timestamps`
- `trg_trips_updated_at`
- `trip_completed_update_total_trips`
- `trigger_credit_driver_on_complete`
- `trip_accepted_trigger`

كل update على `trips` يُشغّل 5-7 functions. هذا ثقيل جداً على performance.

---

### [DB-20] 🟡 `messages` - Duplicate Row في الـ CSV Schema
الصفوف 17 و18 في الـ CSV schema هما نفس البيانات لجدول `messages`. هذا يشير لخلل في الـ schema introspection أو وجود نسختين من schema definition.

---

### [DB-21] 🟡 No pg_cron Scheduled Jobs مرئية
دوال الـ cleanup مثل `cleanup_stale_trips()`, `expire_trip_offers()`, `cleanup_stale_user_presence()` موجودة لكن لا يوجد أي دليل على وجود `pg_cron` jobs تستدعيها. هذا يعني هذه البيانات لا تُنظّف إلا إذا استدعاها الكلاينت يدوياً.

---

### [DB-22] 🟡 `admin_logs` و `notifications` - Never Vacuumed
```
last_vacuum: null  last_analyze: null  vacuum_count: 0
```

هذان الجدولان لم يُعمل عليهما Vacuum أو Analyze منذ الإنشاء.

---

## 🟡 القسم الثالث: Logic الأعمال

### [BL-01] 🚨 `TripBroadcastService` - منطق الأعمال على الكلاينت
**الملف:** `lib/services/trip_broadcast_service.dart`

```dart
// يعمل على موبايل المستخدم - خطير!
final results = await SupabaseService.client
    .from('drivers_profile')
    .select('id, geohash, geohash5, vehicle_type')
    .eq('is_available', true)
    .inFilter('geohash5', searchCells)
    .ilike('vehicle_type', cleanVehicleType);
```

منطق البحث عن السواق وإرسال العروض يعمل من موبايل المستخدم. يقدر يتلاعب فيه بسهولة.

---

### [BL-02] 🔴 `findNearbyDrivers` لا يتحقق من `is_verified`
**الملف:** `lib/services/trip_broadcast_service.dart`

```dart
final results = await SupabaseService.client
    .from('drivers_profile')
    .select(...)
    .eq('is_available', true)  // فقط is_available!
    // ❌ غياب .eq('is_verified', true)
    .inFilter('geohash5', searchCells);
```

سائق غير موثّق (`is_verified = false`) ممكن يستقبل عروض رحلات إذا كان `is_available = true`.

---

### [BL-03] 🔴 `cleanup_stuck_trips` يعمل قبل Authentication
**الملف:** `lib/main.dart`

```dart
void main() async {
  // ...
  await _cleanupStaleTrips();  // ❌ قبل أي login!
  runApp(MyApp(prefs: prefs));
}
```

هذا الـ RPC يعمل بصلاحيات anon (غير مسجل). إذا لم تكن الـ Function محمية بـ `is_admin_user()` check، يمكن لأي شخص استدعاؤها وتعطيل رحلات.

---

### [BL-04] 🔴 `signUpUser` - Race Condition في الـ Upsert
**الملف:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

```dart
try {
  userData = await SupabaseService.client.from('users').upsert({...}).select().single();
} catch (e) {
  // Fallback: SELECT قد يجيب بيانات مستخدم آخر في race condition نادرة
  userData = await SupabaseService.client.from('users').select(...).eq('id', user.id).single();
}
```

في حالة failure، الـ fallback يفعل SELECT بدون retry، وإذا كان الـ user غير موجود (الـ upsert فشل تماماً) سيرمي exception غير handled.

---

### [BL-05] 🔴 `LocationService.startTripTracking` - يقبل أي driverId
**الملف:** `lib/services/location_service.dart`

```dart
void startTripTracking(String driverId) {
  if (_tripTrackingSub != null) return;  // Early return إذا كان tracking شغّال
  _activeTripDriverId = driverId;
  // ...
```

لو `startTripTracking` اُستدعي مرتين بـ driverId مختلف، الأول يُتجاهل والثاني يُتجاهل بسبب `if (_tripTrackingSub != null) return`. الـ tracking يستمر للـ driverId الأول.

---

### [BL-06] 🔴 `_broadcastStream` لا يُعاد تهيئته بعد `stopTripTracking`
**الملف:** `lib/services/location_service.dart`

```dart
void stopTripTracking() {
  _tripTrackingSub?.cancel();
  _tripTrackingSub = null;
  // ...
  _broadcastStream = null;  // ← يُعيّن null
}

Stream<Position> getLocationStream() {
  _broadcastStream ??= _createLocationStream().asBroadcastStream();
  return _broadcastStream!;
}
```

لكن `_tripTrackingSub` يشترك في stream قديمة قبل الـ reset. المشكلة أن الـ subscription تُلغى بـ `cancel()` لكن الـ broadcast stream ممكن يظل مفتوح في الـ background.

---

### [BL-07] 🔴 `UserPresenceService` - Default Location (0, 0) خطير
**الملف:** `lib/services/user_presence_service.dart`

```dart
Future<void> startBroadcasting({double? lat, double? lng}) async {
  _lastLat = lat ?? _lastLat ?? 0.0;  // ❌ 0.0, 0.0 = وسط المحيط الأطلسي!
  _lastLng = lng ?? _lastLng ?? 0.0;
  await _upsertPresence(_lastLat!, _lastLng!);
```

إذا بدأ الـ broadcasting بدون location، يُرسل (0, 0) وهو خطأ جغرافي جسيم. المستخدم سيظهر في وسط المحيط.

---

### [BL-08] 🔴 `ChatbotRepository.fetchAiReply` - Type Safety مكسورة
**الملف:** `lib/features/shared/data/repositories/chatbot_repository.dart`

```dart
final history = await SupabaseService.client
    .from('support_messages')
    .select('message, sender_role')
    .eq('user_id', userId)
    .order('created_at', ascending: false)
    .limit(10);

// history is dynamic, not typed!
if (history is List && history.isNotEmpty) {
  for (final msg in history.reversed) {  // .reversed على List ← يعيد Iterable
```

`.reversed` على `List` من Supabase يعيد `Iterable<dynamic>` مش `List`. في بعض الحالات هذا ممكن يتصرف غير متوقع.

---

### [BL-09] 🔴 `WalletRepository.getDriverEarningsSummary` - بدون Error Handling
**الملف:** `lib/features/wallet/data/repositories/wallet_repository.dart`

```dart
Future<Map<String, dynamic>> getDriverEarningsSummary(String driverId) async {
  final data = await _client  // ❌ لا يوجد try/catch!
      .from('driver_earnings_summary')
      .select()
      .eq('driver_id', driverId)
      .single();
  return data;
}
```

إذا السائق مش عنده earnings بعد، الـ `.single()` يرمي `PostgrestException` ويكسر الـ UI.

---

### [BL-10] 🔴 `R2StorageService` - Thread Safety
**الملف:** `lib/services/r2_storage_service.dart`

```dart
Minio _getClient() {
  if (_minio != null) return _minio!;
  // ❌ غير thread-safe في Dart Isolates
  _minio = Minio(...);
  return _minio!;
}
```

لو رفع ملفان في نفس الوقت، ممكن ينشأ `_minio` مرتين. في Dart هذا نادر لكن ممكن مع Isolates.

---

### [BL-11] 🔴 File Extension Validation سهل التخطي
**الملف:** `lib/services/r2_storage_service.dart`

```dart
final fileExtension = file.path.split('.').last.toLowerCase();
if (!_allowedExtensions.contains(fileExtension)) {
  throw Exception('errorFileUnsupported');
}
```

هذا سهل التحايل عليه: ملف `malware.pdf.exe` يعطي extension = `exe` ويُرفض، لكن `malware.exe` بداخله مسمى `file.jpg` يعطي extension من الاسم الخاطئ. الأصح التحقق من magic bytes.

---

### [BL-12] 🟡 `AuthBloc` - `UserPresenceService.startBroadcasting()` بدون Await
**الملف:** `lib/features/auth/presentation/bloc/auth_bloc.dart`

```dart
UserPresenceService.instance.startBroadcasting();  // ❌ بدون await
emit(AuthAuthenticated(user));
```

الـ broadcasting يبدأ asynchronously لكن الـ state يتغير فوراً. لو الـ broadcasting فشل، لا يوجد error handling.

---

### [BL-13] 🟡 `AuthBloc._onCheckAuthStatus` - 2 Network Calls
**الملف:** `lib/features/auth/presentation/bloc/auth_bloc.dart`

```dart
final result = await _authRepository.getCurrentUser();  // Call 1: users table
// ثم:
final verifiedResult = await _authRepository.getDriverIsVerified(user.id);  // Call 2: drivers_profile
```

عند كل فتح للتطبيق، يعمل 2 sequential network calls. ممكن تُدمج في RPC واحد.

---

### [BL-14] 🟡 `DriverHomeBloc` - يُنشئ `LocationService` مباشرة
**الملف:** `lib/features/driver/presentation/home/bloc/driver_home_bloc.dart`

```dart
final LocationService _locationService = LocationService();  // Singleton
final HeatmapService _heatmapService = HeatmapService.instance;
final DriverHomeRepository _repository = DriverHomeRepository();  // ← Direct instantiation!
```

إنشاء مباشر للـ Repository في الـ Bloc بدون dependency injection. غير قابل للاختبار.

---

### [BL-15] 🟡 `_initRouter` يُستدعى من `build()` - Anti-pattern
**الملف:** `lib/main.dart`

```dart
Widget build(BuildContext context) {
  // ...
  _initRouter(authBloc);  // ❌ Side effect في build!
  return BlocBuilder<ThemeBloc, ThemeState>(...)
```

استدعاء `_initRouter` من داخل `build()` هو anti-pattern. في Flutter، الـ `build()` ممكن يُستدعى عدة مرات. الحل: استدعاء في `initState()` أو `didChangeDependencies()`.

---

### [BL-16] 🟡 `_routerReady` Logic Bug
**الملف:** `lib/main.dart`

```dart
void _initRouter(AuthBloc authBloc) {
  if (!mounted || _routerReady) return;  // إذا !mounted يرجع بدون init!
  _router = AppRouter.router(authBloc);
  _routerReady = true;
}
```

إذا `!mounted` عند أول استدعاء (نادر لكن ممكن في الـ build phase الأولى)، الـ router لن يُهيأ أبداً.

---

### [BL-17] 🟡 `MessagesRepository._loadConversationsFallback` - N+1 Query
**الملف:** `lib/features/shared/data/repositories/messages_repository.dart`

الـ fallback function تجلب آخر 200 رسالة وتعالجها في الذاكرة لاستخراج conversations. هذا غير efficient وبيانات مستخدم فعّال ممكن تفوت الـ limit.

---

### [BL-18] 🟡 `HeatmapService` - Memory Leak في Dispose
**الملف:** `lib/services/heatmap_service.dart`

```dart
void dispose() {
  _isDisposed = true;
  WidgetsBinding.instance.removeObserver(this);
  stopRealtimeUpdates();
  // ❌ لا يُغلق _heatmapController.sink
  // ← Comment يقول "Do NOT close" لكن هذا يعني memory leak
}
```

الـ StreamController مفتوح للأبد كـ Singleton. في كل logout/login، الـ subscriptions قد تتراكم.

---

### [BL-19] 🟡 `CellSubscriptionService` - Driver Data لا يُمسح عند Resubscription
**الملف:** `lib/services/cell_subscription_service.dart`

```
// من الكومنت في الكود:
// FIX: was doing merge which caused offline drivers to persist.
```

تم إصلاح مشكلة جزئية لكن `_driversMap` لا يُمسح فوراً عند `_unsubscribeAll()`. سواقين offline ممكن يظهروا في الخريطة لفترة.

---

### [BL-20] 🟡 `GoRouterRefreshStream` - لا يُلغي الـ Subscription
**الملف:** `lib/core/router/app_router.dart`

```dart
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(...);
  }
  // dispose() يلغي ← OK
  // لكن: stream.asBroadcastStream() ينشئ StreamController داخلي جديد
  // وهذا لا يُغلق عند dispose
}
```

---

### [BL-21] 🟡 `AuthRepositoryImpl.signUpUser` - `is_admin: false` من الكلاينت
**الملف:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

```dart
userData = await SupabaseService.client.from('users').upsert({
  'id': user.id,
  'is_admin': false,  // ← يُرسل من الكلاينت
  ...
}).select().single();
```

الـ RLS تمنع هذا في الحالة العادية، لكن لو في ثغرة في الـ policies أو الـ trigger، ممكن يتلاعب فيه.

---

## 🔵 القسم الرابع: معمارية الكود

### [ARCH-01] 🔴 ملفان نموذجان للـ DriverProfile متناقضان
```
lib/core/models/driver_profile_model.dart         (4080 bytes)
lib/features/auth/data/models/driver_profile_model.dart (4811 bytes)
```

نموذجان مختلفان لنفس الـ entity. من المحتمل أنهما غير متزامنين وسيسببان bugs في بيانات مختلفة.

---

### [ARCH-02] 🔴 `SupabaseService` Static Class - غير قابل للاختبار
**الملف:** `lib/services/supabase_service.dart`

```dart
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
}
```

كل الـ repositories تعتمد على `SupabaseService.client` static. هذا يجعل كتابة unit tests مستحيلة بدون mock frameworks معقدة.

---

### [ARCH-03] 🔴 ملفات ضخمة جداً (God Classes)
```
trip_details_screen.dart (user)     = 60,832 bytes
driver_wallet_screen.dart           = 43,796 bytes
messages_screen.dart                = 46,287 bytes
location_selection_screen.dart      = 48,546 bytes
driver_trips_screen.dart            = 35,676 bytes
driver_trip_details_screen.dart     = 53,490 bytes
```

ملفات بهذا الحجم تحمل مسؤوليات كتيرة جداً، صعبة الصيانة، وبطيئة الـ compile.

---

### [ARCH-04] 🔴 لا يوجد Interface لمعظم Repositories
```
DriverHomeRepository     ← لا Interface
MessagesRepository       ← لا Interface
WalletRepository         ← لا Interface
ChatbotRepository        ← لا Interface
```

`AuthRepository` عنده interface (مميز) لكن باقي الـ repositories لا. هذا يخالف مبدأ Dependency Inversion.

---

### [ARCH-05] 🔴 BLoC مفقودة لبعض الشاشات الرئيسية
```
lib/features/driver/presentation/home/bloc/   ← موجود ✅
lib/features/user/presentation/home/bloc/     ← موجود ✅
lib/features/trips/presentation/bloc/         ← موجود لكن فارغ إلى حد كبير
```

بعض الـ blocs خالية من handlers واضح منها أنها غير مكتملة.

---

### [ARCH-06] 🔴 Direct DB Access من الـ BLoC/Widgets أحياناً
بعض الـ widgets تصل لـ Supabase مباشرة بدون Repository layer، مما يخل ببنية Clean Architecture.

---

### [ARCH-07] 🟡 Singletons بدون Lifecycle Management
```
LocationService.instance
UserPresenceService.instance
HeatmapService.instance
CellSubscriptionService.instance
TripBroadcastService.instance
```

5 singletons مع state داخلي مترابط. عند logout، لو أي منهم لم يُنظّف صح، سيتسرب state من session سابق.

---

### [ARCH-08] 🟡 `withRetry` لا يتعامل مع `Error` (فقط `Exception`)
**الملف:** `lib/core/utils/retry_helper.dart`

```dart
} on Exception catch (e) {  // ❌ فقط Exception
  if (attempt >= maxAttempts || ...) rethrow;
```

في Dart، `Error` و`Exception` مختلفان. `PostgrestException` هو `Exception` لكن بعض Supabase errors قد ترمي `Error` مباشرة وتتجاوز الـ retry.

---

### [ARCH-09] 🟡 `AppRouter` - Static Mutable State
**الملف:** `lib/core/router/app_router.dart`

```dart
class AppRouter {
  static late GoRouter routerInstance;  // ← Mutable static state
```

Static mutable state في classes هو anti-pattern يسبب issues في testing وأحياناً في hot reload.

---

### [ARCH-10] 🟡 `DriverHomeBloc` - Multiple Responsibilities
**الملف:** `lib/features/driver/presentation/home/bloc/driver_home_bloc.dart`

يدير في نفس الوقت:
- Driver availability status
- Location tracking
- Trip offers reception
- Heatmap data
- FCM notifications handling

BLoC واحد بمسؤوليات 5+ مختلفة. يجب تقسيمه.

---

### [ARCH-11] 🟡 لا يوجد Error Boundary في الـ Router
**الملف:** `lib/core/router/app_router.dart`

`GoRouter` مش معاه `errorBuilder` مخصص. أي navigation error سيُظهر Flutter's default error screen.

---

### [ARCH-12] 🟡 `AuthLoading` و `AuthError` يعيدان `null` في الـ Redirect
**الملف:** `lib/core/router/app_router.dart`

```dart
if (authState is AuthError || authState is AuthLoading) {
  return null;  // ← لا redirect، المستخدم يظل في الشاشة الحالية
}
```

أثناء الـ loading، المستخدم يظل في آخر شاشة زار. لو كان في protected screen وأعاد تشغيل التطبيق، يرى المحتوى قبل التحقق من الـ auth.

---

### [ARCH-13] 🟡 Missing Dispose في معظم BLoCs عند Navigation
معظم BLoC subscriptions (Realtime, Timers, Streams) لا تُلغى بشكل مضمون عند الـ navigation للخلف، مما يؤدي لـ memory leaks.

---

### [ARCH-14] 🟡 `ConnectivityService().init()` بدون await ونتيجة
**الملف:** `lib/main.dart`

```dart
ConnectivityService().init();  // ❌ بدون await، بدون assignment
```

الـ `ConnectivityService` يُنشأ وينتهي فوراً لو مش Singleton. وإذا كان Singleton، الـ init يحدث asynchronously بدون guarantee.

---

### [ARCH-15] 🟡 `FCMService` - بدون Deduplication
**الملف:** `lib/services/fcm_service.dart`

في حالة الـ foreground، `onMessage.listen` يعالج كل رسالة. لو نفس الـ notification وصلت مرتين (retry من FCM)، يُعالجها مرتين.

---

### [ARCH-16] 🟡 `AppBlocObserver` مسجّل لكن بدون Crash Reporting
**الملف:** `lib/core/bloc_observer.dart`

```dart
Bloc.observer = AppBlocObserver();
```

الـ observer موجود لكن كل الـ errors تُطبع فقط بـ `debugPrint`. في production، `debugPrint` لا يعمل. لا يوجد Sentry أو Crashlytics.

---

### [ARCH-17] 🟡 لا يوجد Pagination في معظم Lists
- `trips` screen: تجلب كل الرحلات
- `notifications`: تجلب كل الإشعارات
- `conversations`: تجلب آخر 200 رسالة

بدون pagination حقيقي، في المستخدمين القدامى، الـ loading سيطول وقد يسبب crash من memory.

---

### [ARCH-18] 🟡 `MultiRepositoryProvider` في root - جميع Services تُنشأ دفعة واحدة
**الملف:** `lib/main.dart`

```dart
RepositoryProvider<R2StorageService>(create: (_) => R2StorageService()),
RepositoryProvider<AuthRepositoryImpl>(create: (context) => AuthRepositoryImpl(...)),
```

جميع الـ services تُنشأ فور فتح التطبيق حتى لو المستخدم غير مسجل. يجب استخدام lazy initialization.

---

## 🟣 القسم الخامس: واجهة المستخدم (UI/UX)

### [UI-01] 🔴 Splash Screen بدون Timeout
إذا `checkAuthStatus` تأخر (شبكة بطيئة)، المستخدم يظل في الـ splash للأبد. لا يوجد timeout أو retry mechanism.

---

### [UI-02] 🔴 `AuthLoading` لا يُظهر Loading Indicator في بعض الشاشات
`AuthError` و`AuthLoading` في الـ redirect يعيدان `null`، مما يعني المستخدم يظل في الشاشة الحالية مع أي loading indicator أو error message.

---

### [UI-03] 🔴 Theme Flash عند الـ Startup
```dart
BlocProvider<ThemeBloc>(
  create: (_) => ThemeBloc(widget.prefs)..add(LoadSavedTheme()),
),
```

الـ ThemeBloc يبدأ بـ default theme ثم يُحدَّث لما `LoadSavedTheme` يعمل. هذا يسبب flash من light إلى dark (أو العكس) عند فتح التطبيق.

---

### [UI-04] 🔴 `payment_method` مصمم في DB لكن غير مكتمل في UI
9 أعمدة 100% NULL تعني features مصممة في Backend لكن UI مش جاهز. المستخدم ممكن يرى عناصر UI فارغة أو مكسورة.

---

### [UI-05] 🟡 لا يوجد Error State لمعظم Screens
معظم الـ screens تعرض loading أو data، لكن في حالة network error، لا يوجد retry button أو error message واضح.

---

### [UI-06] 🟡 `conversations_screen.dart` (23KB) و `messages_screen.dart` (46KB) - Monolithic Widgets
شاشات ضخمة بدون تقسيم لـ sub-widgets. أي تعديل بسيط يستدعي تعديل ملف ضخم، وcompilation بطيء.

---

### [UI-07] 🟡 Localization Files ضخمة جداً
```
app_localizations.dart    = 77,914 bytes
app_localizations_ar.dart = 34,450 bytes
```

ملفات generated ضخمة. في كل build، Flutter يعيد تحليلها. ممكن يبطئ الـ build time.

---

### [UI-08] 🟡 `driver_offer_overlay.dart` (15KB) - Overlay بدون State Management
الـ overlay للعروض مكتوب كـ stateful widget ضخم. لو الـ app ذهب للخلفية أثناء العرض، state ممكن يضيع.

---

### [UI-09] 🟡 `ride_offer_overlay.dart` (16KB) - ملف Overlay ضخم آخر
ملف overlay منفصل مع logic مماثل. يجب دمجهم أو استخدام shared component.

---

### [UI-10] 🟡 لا يوجد Empty State UI لكثير من الشاشات
شاشات مثل `trips_screen` و`notifications_screen` ممكن تعرض قائمة فارغة بدون رسالة "لا توجد رحلات" واضحة.

---

### [UI-11] 🟡 Deep Link Handling غير مكتمل
الـ router يستقبل `?tripId=` كـ query params لكن لا يوجد handling لـ deep links من FCM notifications.

---

### [UI-12] 🟡 `AppDrawer` (16KB) - Drawer ضخم جداً
```
lib/core/widgets/app_drawer.dart = 16,056 bytes
```

Drawer widget بهذا الحجم يحتوي على كثير من logic يجب أن يكون في BLoC أو separate widgets.

---

## ⚫ القسم السادس: التشغيل والإنتاج

### [OPS-01] 🚨 لا يوجد pg_cron Jobs لـ Cleanup Functions
دوال الـ cleanup الحرجة:
- `cleanup_stale_trips()`
- `expire_trip_offers()`
- `cleanup_stale_user_presence()`
- `cleanup_stuck_trips()`
- `cleanup_orphan_trip_offers()`

لا يوجد أي evidence على وجود scheduled jobs لها. تُستدعى فقط من الكلاينت أو من triggers.

**الحل الفوري:**
```sql
SELECT cron.schedule('expire-offers', '*/5 * * * *', 'SELECT expire_trip_offers()');
SELECT cron.schedule('cleanup-stale', '0 * * * *', 'SELECT cleanup_stale_trips()');
```

---

### [OPS-02] 🚨 لا يوجد Monitoring أو Alerting
لا يوجد أي integration مع:
- Sentry / Crashlytics لـ error tracking
- Prometheus / Grafana لـ performance
- PagerDuty / alerts عند failure

في production، لو التطبيق كسر، لن تعلم إلا من تقارير المستخدمين.

---

### [OPS-03] 🔴 `user_presence` يحتاج UNLOGGED TABLE أو Redis
**من وصف الـ schema:**
```
"Consider UNLOGGED table or Redis at production scale."
```

97K+ updates على جدول logged مع bloat 85%. في production مع 1000+ مستخدم، هذا سينهار.

---

### [OPS-04] 🔴 لا يوجد Vacuum Schedule صريح
معظم الجداول تعتمد فقط على autovacuum الافتراضي. مع bloat 60-85% في جداول حرجة، يجب إضافة vacuum schedule أكثر عدوانية.

**الحل الفوري:**
```sql
ALTER TABLE user_presence SET (autovacuum_vacuum_scale_factor = 0.01);
ALTER TABLE drivers_profile SET (autovacuum_vacuum_scale_factor = 0.01);
VACUUM ANALYZE user_presence;
VACUUM ANALYZE drivers_profile;
VACUUM ANALYZE users;
VACUUM ANALYZE vehicle_types;
```

---

### [OPS-05] 🔴 اثنان من APIs يكشفان معلومات الـ Project
```
projectId: 'arai-449ca'         ← في firebase_options.dart
storageBucket: 'arai-449ca.firebasestorage.app'
authDomain: 'arai-449ca.firebaseapp.com'
```

اسم المشروع مكشوف. يسمح باستهداف محدد في هجمات.

---

### [OPS-06] 🔴 لا يوجد GDPR/Data Deletion Implementation
لا يوجد:
- `deleted_at` column في `users`
- آلية لحذف بيانات المستخدم بشكل كامل
- سياسة احتفاظ بالبيانات

هذا مشكلة قانونية في أي سوق يطبق GDPR أو قوانين حماية البيانات.

---

### [OPS-07] 🔴 اثنان من Edge Functions غير موثّقتين: `send-fcm` و`chatbot-ai`
```dart
await SupabaseService.client.functions.invoke('send-fcm', body: {...});
await SupabaseService.client.functions.invoke('chatbot-ai', body: {...});
```

هذه الـ functions غير موجودة في الكود المُرسَل. لو لم تكن deployed، ستفشل كل الـ notifications والـ chatbot.

---

### [OPS-08] 🟡 `admin_logs` مفعّل لكن لا يُملأ
الجدول موجود مع سياسات صح، لكن 0 rows. يعني `log_admin_action()` مش بتُستدعى في أي مكان في الكود المرئي. كل عمليات الأدمن غير مسجّلة.

---

### [OPS-09] 🟡 `trips` fillfactor = 85 لكن HOT updates = 22% فقط
الـ fillfactor مضبوط لتحسين HOT updates، لكن 78% من الـ updates ما بتستفيدش منه. يعني الأعمدة المُعدَّلة عليها indexes تمنع HOT.

---

### [OPS-10] 🟡 لا يوجد Connection Pooling Configuration مرئية
لا يوجد دليل على إعداد PgBouncer أو Supabase connection pooling mode. في production مع كثير من connections من الكلاينت، ممكن يصل لـ connection limit.

---

### [OPS-11] 🟡 `debugPrint` في كل Production Code
```dart
debugPrint('🔍 TripBroadcast: ...');  // يظهر في debug mode فقط
debugPrint('📍 LocationService: ...');
```

`debugPrint` في Flutter يُطبع في debug mode فقط، لكن الـ string interpolation تحدث دائماً. هذا overhead في production.

**الحل:**
```dart
if (kDebugMode) debugPrint('...');
```

---

### [OPS-12] 🟡 لا يوجد App Version Check
لا يوجد آلية لإجبار المستخدمين على تحديث التطبيق عند تغيير API. لو الـ schema تغير، النسخ القديمة ستنكسر.

---

### [OPS-13] 🟡 `pricing_config` مع 43 heap_blocks.hit بدون تفسير
**من وصف الـ schema:**
```
"Has 43 heap_blocks.hit — investigate via pg_stat_statements."
```

هناك cache hits غير متوقعة على `pricing_config` يجب التحقيق فيها.

---

### [OPS-14] 🟡 لا يوجد Index على `drivers_profile.vehicle_type`
كل query تبحث عن سواقين بنوع سيارة معين تعمل seq scan:
```sql
.ilike('vehicle_type', cleanVehicleType)  -- slow!
```

**الحل:**
```sql
CREATE INDEX idx_drivers_profile_vehicle_type ON drivers_profile USING btree(lower(vehicle_type));
```

---

### [OPS-15] 🟡 `wallets` - مفيش Max Balance أو Fraud Protection
لا يوجد:
- `CHECK constraint` على الـ balance
- Max withdrawal amount validation على مستوى DB
- Fraud detection على المعاملات

سائق يقدر نظرياً يطلب سحب أكثر من رصيده (يجب أن يكون في `request_driver_withdrawal` لكن يحتاج تدقيق).

---

## 📊 ملخص الأولويات

### 🚨 إصلاح فوري (قبل Production):
1. **[SEC-02]** نقل R2 uploads لـ Edge Function
2. **[SEC-04]** تقييد الـ users RLS policy
3. **[SEC-10]** إزالة البيانات الحساسة من drivers_profile visibility
4. **[SEC-11]** نقل trip broadcasting لـ server-side
5. **[DB-01]** `VACUUM ANALYZE user_presence` فوراً
6. **[DB-04]** إصلاح NULL geohash للسواقين الموجودين
7. **[OPS-01]** إضافة pg_cron jobs للـ cleanup

### 🔴 أسبوع أول:
8. **[SEC-03]** نقل AI calls لـ Edge Function
9. **[SEC-05]** إخفاء FCM tokens من RLS
10. **[DB-02, DB-03, DB-07]** Vacuum جميع الجداول
11. **[BL-02]** إضافة `is_verified` check في findNearbyDrivers
12. **[ARCH-01]** دمج duplicate driver profile models
13. **[OPS-02]** إضافة Sentry/Crashlytics

### 🟡 شهر أول:
14. **[DB-11]** حذف الـ indexes غير المستخدمة
15. **[DB-05, DB-06]** تنظيف الـ trips schema (duplicate columns, NULL columns)
16. **[ARCH-02]** تحويل SupabaseService لـ injectable service
17. **[ARCH-04]** إضافة interfaces للـ repositories
18. **[OPS-03]** تقييم UNLOGGED TABLE لـ user_presence
19. **[OPS-06]** تطبيق GDPR data deletion

---

## 🔧 خطة الـ Quick Fixes الفورية

```sql
-- 1. Vacuum حرجة
VACUUM ANALYZE user_presence;
VACUUM ANALYZE drivers_profile;
VACUUM ANALYZE users;
VACUUM ANALYZE vehicle_types;

-- 2. تحديث fillfactor للجداول الديناميكية
ALTER TABLE user_presence SET (autovacuum_vacuum_scale_factor = 0.01);
ALTER TABLE drivers_profile SET (autovacuum_vacuum_scale_factor = 0.01);

-- 3. إصلاح geohash للسواقين الحاليين
UPDATE drivers_profile SET
  geohash = encode_geohash(current_lat, current_lng, 9),
  geohash5 = encode_geohash(current_lat, current_lng, 5)
WHERE current_lat IS NOT NULL AND current_lng IS NOT NULL
  AND (geohash IS NULL OR geohash5 IS NULL);

-- 4. Index مفقود
CREATE INDEX idx_drivers_profile_vehicle_type 
ON drivers_profile USING btree(lower(vehicle_type)) WHERE is_available = true;

CREATE INDEX idx_trips_user_status
ON trips USING btree(user_id, status);

-- 5. حذف indexes غير مستخدمة
DROP INDEX IF EXISTS idx_notifications_user_created;
DROP INDEX IF EXISTS idx_wallet_txns_wallet_created;
DROP INDEX IF EXISTS idx_withdrawal_driver_created;

-- 6. RLS Fix للـ users table
CREATE POLICY "Users can see limited public info"
ON users FOR SELECT USING (
  (auth.uid() = id) OR is_admin_user()
);
-- ثم احذف policy "Authenticated users can see basic user info"
```

---

*تم إعداد هذا التقرير بتحليل شامل لـ 268 ملف Dart + 959 صف من بيانات PostgreSQL Schema Introspection.*
