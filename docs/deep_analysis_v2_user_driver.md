# تقرير التحليل العميق — الإصدار الثاني (User + Driver فقط)
**تاريخ التحليل:** 2026-05-16  
**الملفات المحللة:** 184 ملف Dart (مُقرأة كاملة) + Supabase Schema CSV (32 جدول، 87 دالة، 17 View)  
**نطاق التقرير:** جانب المستخدم (User) + جانب السائق (Driver) **فقط**  
**ملاحظة:** هذا الإصدار يُصحح أخطاء التقرير السابق ويضيف اكتشافات جديدة بناءً على قراءة كاملة للكود.

---

## فهرس المحتويات

1. [ملخص تنفيذي](#1-ملخص-تنفيذي)
2. [تصحيحات التقرير السابق](#2-تصحيحات-التقرير-السابق)
3. [مشاكل مؤكدة من التقرير السابق](#3-مشاكل-مؤكدة-من-التقرير-السابق)
4. [اكتشافات جديدة — أخطاء حرجة](#4-اكتشافات-جديدة--أخطاء-حرجة)
5. [اكتشافات جديدة — مشاكل Architecture](#5-اكتشافات-جديدة--مشاكل-architecture)
6. [جداول وViews ودوال DB غير مستغلة](#6-جداول-وviews-ودوال-db-غير-مستغلة-userdriver-فقط)
7. [خلاصة الأولويات الشاملة](#7-خلاصة-الأولويات-الشاملة)

---

## 1. ملخص تنفيذي

| الجانب | حالة | ملاحظة |
|--------|------|---------|
| User Features | ⚠️ 5 ميزات ناقصة | بعد تصحيح التقرير السابق |
| Driver Features | ⚠️ 2 ميزات ناقصة | Target Route وBonusLedger كانا مطبقَين |
| أخطاء حرجة جديدة | ❌ 4 أخطاء | تكتشف لأول مرة |
| مشاكل Architecture | ⚠️ 5 مشاكل | بعضها لم يُذكر من قبل |
| كود ميت مؤكد | ❌ 3 عناصر | بعد إزالة ما ثبت أنه مستخدم |

---

## 2. تصحيحات التقرير السابق

### ✅ الخطأ 1: ComplaintsScreen لا تعرض admin_reply

**التقرير السابق قال:** "`ComplaintsScreen` لا تعرض رد الأدمن"

**الحقيقة بعد قراءة الكود:**  
`_ComplaintCard` يقرأ `admin_reply` ويعرضه بشكل جميل مع أيقونة وخلفية خضراء:

```dart
// في complaints_screen.dart — السطر 184 تقريباً
final adminReply = complaint['admin_reply'];
// ...
if (adminReply != null && adminReply.toString().trim().isNotEmpty) {
  // عرض كامل في Container بتصميم جميل ✅
}
```

**الخلاصة:** هذه النقطة سبق حلّها. ✅

---

### ✅ الخطأ 2: لا يوجد UI لـ Target Route / Corridor

**التقرير السابق قال:** "لا يوجد أي UI يسمح للسائق بتفعيل أو إيقاف هذه الميزة"

**الحقيقة بعد قراءة الكود:**  
`DriverHomeScreen` فيها تطبيق كامل ومتكامل:
- `_CorridorPickerScreen` — شاشة كاملة يختار فيها السائق نقطة البداية والنهاية على الخريطة
- يرسم الـ route على الخريطة ويحفظ في DB مباشرة
- يدعم radius sliders للتحكم في نطاق القبول
- زر حذف الممر
- يستعيد الممر المحفوظ تلقائياً من DB عند الفتح

**الخلاصة:** هذه الميزة مطبقة بالكامل. ✅

---

### ✅ الخطأ 3: driver_bonus_ledger غير مستخدم

**التقرير السابق قال:** "لا توجد شاشة تعرض تاريخ المكافآت"

**الحقيقة بعد قراءة الكود:**  
`BonusRepository.getBonusHistory()` تجلب من `driver_bonus_ledger` مع join على `bonus_rules`، و`DriverBonusScreen` تعرضها في section "سجل المكافآت" كامل مع التواريخ. ✅

---

### ⚠️ تصحيح جزئي: NotificationModel لا يقرأ title_ar/body_ar

**التقرير السابق قال:** "لا يوجد: titleAr, bodyAr"

**الحقيقة:** الـ model يحتويها ويحولها من JSON، بل ويحتوي على helper methods جاهزة:

```dart
// في notification_model.dart — موجود بالكامل ✅
final String? titleAr;
final String? bodyAr;

String localizedTitle(String language) {
  if (language == 'ar' && titleAr != null && titleAr!.isNotEmpty) return titleAr!;
  return title;
}
String localizedBody(String language) {
  if (language == 'ar' && bodyAr != null && bodyAr!.isNotEmpty) return bodyAr!;
  return message;
}
```

**لكن المشكلة الحقيقية:** `NotificationsScreen` لا تستخدم هذه الـ helpers على الإطلاق:

```dart
// في notifications_screen.dart — المشكلة هنا:
_NotificationCard(
  title: notif.title,    // ❌ دايماً الإنجليزي
  message: notif.message, // ❌ دايماً الإنجليزي
)

// الصح:
title: notif.localizedTitle(Localizations.localeOf(context).languageCode),
message: notif.localizedBody(Localizations.localeOf(context).languageCode),
```

**الخلاصة:** المشكلة موجودة لكن أبسط من التقرير السابق — سطران فقط يحتاجان تعديل.

---

## 3. مشاكل مؤكدة من التقرير السابق

### 3.1 رفع صورة بروفايل المستخدم — مؤكد ❌

**الموقع:** `user_profile_screen.dart`

الـ `CircleAvatar` لا يحتوي `GestureDetector` ولا أي callback. الـ `ProfileBloc` يقبل `avatar_url` في `_allowedProfileFields` و`R2StorageService` موجود في الـ `main.dart`، لكن لا يوجد أي wire-up في UI.

**ملاحظة إضافية:** `DriverProfileScreen` فيها Stack مع Icon.edit كزر تعديل الصورة — لكنه **ديكوري تماماً** ليس عليه أي `GestureDetector`. راجع الاكتشافات الجديدة.

---

### 3.2 لا يوجد شاشة كوبونات — مؤكد ❌

`UserHomeBloc` يجلب الكوبونات ويخزنها في `UserHomeLoaded.coupons`، لكن لا مسار ولا شاشة تعرضها. المستخدم لا يعرف كوبوناته إلا بكتابتها يدوياً في Pricing.

---

### 3.3 Scheduled Trips — مؤكد ❌

`TripEntity.scheduledAt` موجود في الـ model وJSON، لكن لا `DateTimePicker` في أي شاشة.

---

### 3.4 AppConfigRepository لا يُستدعى — مؤكد ❌

**الموقع:** `lib/core/repositories/app_config_repository.dart`

بحثت في كل الملفات الـ 184:

```bash
grep -rn "AppConfigRepository" lib/
# ← لا نتائج خارج ملف تعريف الكلاس نفسه ❌
```

خمس methods كاملة + `watchConfig()` stream مكتوبة وجدول `app_config` فيه 7 records في DB، و`app_config` مُدرج في `realtime_tables`. لكن التطبيق لا يستدعي شيئاً منها. يعني:
- maintenance mode مش بيُفعَّل
- feature flags مش بتشتغل
- لا يوجد إجبار تحديث التطبيق
- الـ Realtime config watch مش بيشتغل

---

### 3.5 تضارب pricing_config vs vehicle_types — مؤكد ❌

| الجدول | من يكتب فيه | من يقرأ منه |
|--------|------------|------------|
| `vehicle_types` | الداشبورد (`admin_update_pricing` تكتب في **pricing_config**) | Flutter يقرأ منه |
| `pricing_config` | `admin_update_pricing()` | **لا أحد في Flutter** |

**الأثر:** لو الأدمن غيّر سعر الكيلومتر من الداشبورد، `pricing_config` يتحدث، لكن Flutter يستمر يقرأ من `vehicle_types` القديمة. وجود `_fn_sync_pricing_from_vehicle_types` trigger يوحي بمحاولة مزامنة قديمة لكنها ناقصة.

---

### 3.6 driver_revision_requests مش موجود في Flutter — مؤكد ❌

```bash
grep -rn "driver_revision" lib/
# ← لا نتائج ❌
```

السائق المرفوض وثائقه لا يعرف ما المطلوب. `PendingVerificationScreen` تعرض فقط نص عام "حسابك تحت المراجعة" وزر Logout — بدون أي reference لـ `driver_revision_requests`.

---

### 3.7 TripOfferModel — حقول ناقصة ❌

```dart
// ما هو موجود في trip_offer_model.dart:
class TripOfferModel {
  final String id, tripId, driverId;
  final TripOfferStatus status;
  final DateTime? createdAt, respondedAt, updatedAt;
  // ❌ proposed_price مفقود
  // ❌ driver_location_lat مفقود
  // ❌ driver_location_lng مفقود
  // ❌ pickup_address مفقود
  // ❌ destination_address مفقود
  // ❌ distance_km مفقود
}
```

`SearchingScreen` يقرأ `offer['proposed_price']` من raw map بدون type safety. `DriverRequestFeedScreen` يقرأ `offer['pickup_address']`, `offer['destination_address']`, `offer['proposed_price']`, `offer['distance_km']` كلها من raw maps بنفس الطريقة الخطرة.

---

### 3.8 markAllAsRead لا تُستدعى — مؤكد ❌

`NotificationsRepository.markAllAsRead()` مكتوبة كاملاً. `NotificationsScreen` تستدعي فقط `_markAsRead(id)` للإشعار الفردي عند الضغط عليه. لا توجد أي استدعاء لـ `markAllAsRead` لا عند فتح الشاشة ولا بأي زر.

---

### 3.9 UserProfileRepository — كلاس ميتة تماماً ❌

```dart
// lib/features/user/domain/repositories/user_profile_repository.dart
abstract class UserProfileRepository {
  Future<Map<String, dynamic>?> getUserProfile(String userId);
  Future<void> updateProfile(String userId, Map<String, dynamic> data);
}
// ← لا implementation، لا استخدام، لا وارثين
```

`ProfileBloc` يستدعي Supabase مباشرة. هذه الكلاس يجب حذفها أو تطبيقها.

---

## 4. اكتشافات جديدة — أخطاء حرجة

### 4.1 🔴 DriverRequestFeedScreen يرفض بـ status='declined' (خطأ DB)

**الموقع:** `driver_request_feed_screen.dart` — دالة `_reject()`

```dart
Future<void> _reject(String offerId) async {
  await SupabaseService.client
      .from('trip_offers')
      .update({'status': 'declined'})  // ❌ القيمة خطأ!
      .eq('id', offerId);
}
```

**قيم الـ Enum الحقيقية في DB:**
```sql
-- من الـ schema:
-- TripOfferStatus: pending | accepted | rejected | expired
-- 'declined' مش موجود ❌
```

**الأثر العملي:** عند الرفض من شاشة "طلبات الرحلات":
- DB يرفض القيمة بـ constraint violation (أو يقبلها إن كانت `text` بدون enum في الـ check — لكنه يكسر الـ logic)  
- الـ offer لا يُحذف من الـ stream لأن الـ status لا يتغير لـ `rejected`
- الكارت يظل ظاهراً للسائق ويشوفه مرة ثانية
- يجب تغيير `'declined'` إلى `'rejected'`

---

### 4.2 🔴 FCM deep-link يرسل Driver إلى شاشة User

**الموقع:** `fcm_service.dart` — دالة `_handleMessageOpen()`

```dart
case 'new_message':
  final senderId = message.data['senderId'];
  final tripId = message.data['tripId'];
  if (tripId != null) {
    router.go('${AppRoutes.userMessages}?tripId=$tripId');  // ❌
  } else if (senderId != null) {
    router.go('${AppRoutes.userMessages}?otherUserId=$senderId'); // ❌
  }
  break;
```

**الأثر:** لو السائق تلقّى إشعار رسالة جديدة وضغط عليه:
- `AppRoutes.userMessages` = `/user/messages`
- Router سيحاول navigate إلى شاشة المستخدم وهو Driver authenticated
- يصطدم بالـ redirect في `AppRouter` الذي سيعيده إلى `driverHome`

**الحل:**
```dart
final user = SupabaseService.currentUser;
final role = // اقرأ الـ role
final route = role == 'driver' ? AppRoutes.driverMessages : AppRoutes.userMessages;
router.go('$route?tripId=$tripId');
```

---

### 4.3 🔴 NotificationsScreen تراوت الـ Driver إلى شاشة Trip خاطئة

**الموقع:** `notifications_screen.dart` — دالة `_onNotificationTap()`

```dart
} else if (notif.type == 'trip' && notif.referenceId != null) {
  context.go('${AppRoutes.userTripDetails}?tripId=${notif.referenceId}');
  // ❌ دايماً User route حتى لو الشاشة مفتوحة من DriverNotifications
}
```

**الأثر:** السائق بيضغط على إشعار رحلة → يوديه `user/trip-details` → screen مصممة لـ User وتستخدم `TripsBloc` مش `TripDetailsBloc`. بيحدث خطأ في الـ BLoC provisioning.

---

### 4.4 🟠 زر تعديل صورة السائق — ديكور فارغ

**الموقع:** `driver_profile_screen.dart`

```dart
Stack(
  alignment: Alignment.bottomRight,
  children: [
    CircleAvatar(
      radius: 52,
      // ...
    ),
    Container(
      // زر الـ edit — يبدو قابلاً للضغط لكن:
      child: Icon(Icons.edit, size: 14),
    ),
    // ❌ لا GestureDetector، لا InkWell، لا onTap
  ],
)
```

**الأثر:** السائق يرى أيقونة قلم رصاص → يضغط عليها → لا يحدث شيء. تجربة مستخدم سيئة تحيّر السائق.

**مقارنة:** `UserProfileScreen` تُظهر CircleAvatar بدون أي أيقونة edit — أوضح وإن كانت الوظيفة ناقصة أيضاً.

---

## 5. اكتشافات جديدة — مشاكل Architecture

### 5.1 UserWalletScreen — State Management مخالف لباقي التطبيق

**الموقع:** `user_wallet_screen.dart`

```dart
// user_wallet_screen.dart — يعرّف Local State classes خاصة:
abstract class _UserWalletState {}
class _Loading extends _UserWalletState {}
class _Loaded extends _UserWalletState { ... }
class _Error extends _UserWalletState { ... }

class _UserWalletScreenState extends State<UserWalletScreen>
    with SingleTickerProviderStateMixin {
  _UserWalletState _state = _Loading();
  // يستخدم setState() مباشرة
}
```

**في المقابل:** `DriverWalletScreen` تستخدم `WalletCubit` المُعدّ خصيصاً لهذا الغرض وهو مُدرج في `WalletCubit` بالفعل.

**الأثر:**
- الـ `WalletCubit` موجود ومكتوب للمحفظتين لكن يُستخدم للسائق فقط
- لو في bug في user wallet، صعب تتبعه لأن الـ state مش في BLoC
- لو فيه realtime update لمحفظة المستخدم، `UserWalletScreen` عندها `StreamSubscription` خاصة بـ `setState` بدلاً من استخدام `WalletCubit.watchUserWallet`

---

### 5.2 ثلاثة مسارات مختلفة لبيانات الأرباح

```
مسار 1: DriverHomeBloc → DriverHomeRepository.getEarningsSummary()
         → DriverEarningsHelper.fetch(userId)
         → driver_earnings_summary VIEW فقط

مسار 2: WalletRepository.getDriverEarningsSummary()
         → driver_earnings_summary VIEW
         + get_driver_earnings_detailed RPC
         (أكثر تفصيلاً من المسار 1)

مسار 3: DriverProfileRepository.loadDriverProfile()
         → driver_earnings_summary VIEW مباشرة
         (مختلف عن DriverEarningsHelper)
```

**الأثر العملي:**
- الأرقام المعروضة في Home قد تختلف عن Wallet عن Profile
- في حالة تغيير schema الـ View، يحتاج تعديل في 3 أماكن مختلفة
- المسار 2 يجلب `earnings_7d` و`earnings_30d` بينما المسار 1 لا يجلبهما

---

### 5.3 Notifications — الـ Screen لا تستخدم Realtime Stream

**الموقع:** `notifications_screen.dart` + `notifications_repository.dart`

المستودع يحتوي على:
```dart
// notifications_repository.dart — مكتوب ومستعد:
Stream<List<NotificationModel>> watchNotifications() { ... } // ✅ موجود
```

`NotificationsScreen` تستدعي `_loadNotifications()` مرة واحدة فقط (Future)، **لا تستمع** للـ `watchNotifications()` stream.

**الأثر:** لو وصل إشعار جديد والمستخدم في شاشة الإشعارات، الشاشة **لا تتحدث** تلقائياً — يضطر المستخدم للخروج والعودة.

**مقارنة:** `ComplaintsScreen` تستخدم `StreamBuilder` بشكل صحيح مع `myComplaintsStream()`.

---

### 5.4 SearchingScreen — اسم السائق لا يُعرض

**الموقع:** `searching_screen.dart`

```dart
// في offers list:
Text(
  'سائق متاح',  // ❌ نص ثابت
  style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
),
```

`trip_offers` يجتمع مع `drivers_profile` في بعض queries. `DriverRequestFeedScreen` يجلب `pickup_address` و`destination_address` من الـ offer مباشرة. لكن `SearchingBloc` لا يجلب بيانات السائق عند ورود العرض.

**الحل المطلوب:** عند ورود offer، جلب `driver_id` وعمل join على `public_driver_profiles` View لعرض الاسم والتقييم.

---

### 5.5 DriverHomeScreen — نصوص Hardcoded بالعربي

**الموقع:** `driver_home_screen.dart` — Bottom Nav

```dart
BottomNavItem(
  icon: Icons.list_alt_outlined,
  activeIcon: Icons.list_alt_rounded,
  label: 'الرحلات',   // ❌ hardcoded
),
BottomNavItem(
  icon: Icons.alt_route_outlined,
  activeIcon: Icons.alt_route_rounded,
  label: 'الوجهة',   // ❌ hardcoded
),
```

التطبيق يدعم العربي والإنجليزي ويحتوي على `AppLocalizations` كاملة — هذين النصين يظلان بالعربي حتى لو غيّر المستخدم اللغة للإنجليزية.

---

## 6. جداول وViews ودوال DB غير مستغلة (User/Driver فقط)

### الجداول

| الجدول | المشكلة | الأولوية |
|--------|---------|---------|
| `driver_revision_requests` | لا يُقرأ نهائياً من Flutter | 🔴 عالية |
| `pricing_config` | Flutter يقرأ من `vehicle_types` بدلاً منه | 🔴 عالية |
| `driver_service_areas` + `service_areas` | لا يوجد UI يعرض المناطق للسائق | 🟡 منخفضة |
| `coupon_audit_log` | لا يُقرأ (OK — للتحليل فقط) | — |

### الـ Views

| View | المشكلة |
|------|---------|
| `user_trip_stats` | إحصاءات رحلات المستخدم (total_trips, avg_rating, etc.) لا تُعرض في Profile |
| `public_user_profiles` | التطبيق يقرأ من `users` مباشرة بدلاً منها |
| `driver_public_profile` | نفس المشكلة — يُقرأ من `users` + `drivers_profile` يدوياً |

### الدوال

| الدالة | المشكلة |
|--------|---------|
| `fn_coupon_usage_timeline()` | مفيدة لشاشة الكوبونات الناقصة |
| `get_nearby_drivers_secure()` | `UserHomeBloc` يستخدم cell-based subscription بدلاً منها (ليست مشكلة بالضرورة) |
| `set_driver_target_route()` | `DriverHomeScreen` تكتب مباشرة في `drivers_profile` بدلاً من استخدامها |

**ملاحظة:** `set_driver_target_route()` الدالة ليست مستخدمة رغم وجود UI كامل للممر — الـ Screen يكتب مباشرة في `drivers_profile` بدلاً من استدعاء الدالة. هذا يتجاوز أي validation/logic في الدالة.

---

## 7. خلاصة الأولويات الشاملة

### 🔴 أولوية عالية جداً — قبل Launch

| # | المهمة | الموقع | الخطورة |
|---|--------|--------|---------|
| 1 | **Fix status='declined' → 'rejected'** في reject offer | `driver_request_feed_screen.dart` سطر 88 | Bug صامت يكسر الـ flow |
| 2 | **Fix FCM deep-link** للسائق | `fcm_service.dart` → `_handleMessageOpen` | سائق يُرسل إلى شاشة خاطئة |
| 3 | **Fix NotificationsScreen tap** لنوع 'trip' | `notifications_screen.dart` → `_onNotificationTap` | Driver يُرسل إلى User screen |
| 4 | **تفعيل AppConfigRepository** | `main.dart` بعد init | maintenance_mode، force update |
| 5 | **حل تضارب pricing_config vs vehicle_types** | `PricingBloc` أو الداشبورد | أسعار الأدمن لا تنعكس في التطبيق |
| 6 | **عرض driver_revision_requests للسائق** | `PendingVerificationScreen` + `DriverProfileScreen` | السائق لا يعرف سبب الرفض |

---

### 🟠 أولوية متوسطة — Sprint أول بعد Launch

| # | المهمة | الموقع |
|---|--------|--------|
| 7 | **رفع صورة بروفايل المستخدم** | `UserProfileScreen` + `ProfileBloc` |
| 8 | **إصلاح زر edit صورة السائق** (ديكوري حالياً) | `DriverProfileScreen` |
| 9 | **استخدام localizedTitle/localizedBody** في NotificationsScreen | `notifications_screen.dart` سطر 154-155 |
| 10 | **تحويل UserWalletScreen لـ WalletCubit** | `user_wallet_screen.dart` |
| 11 | **تفعيل watchNotifications() stream** بدل one-shot future | `notifications_screen.dart` |
| 12 | **استدعاء markAllAsRead عند فتح الشاشة** | `notifications_screen.dart` |
| 13 | **استدعاء set_driver_target_route RPC** بدل الكتابة المباشرة | `_CorridorPickerScreen._save()` |

---

### 🟡 أولوية منخفضة — تحسينات

| # | المهمة | الموقع |
|---|--------|--------|
| 14 | **شاشة كوبونات المستخدم** | route جديد + screen جديدة |
| 15 | **عرض اسم السائق في Searching** | `searching_screen.dart` — driver name بدل "سائق متاح" |
| 16 | **Scheduled Trips UI** | `PricingScreen` DateTimePicker |
| 17 | **حذف UserProfileRepository** أو تطبيقها | `user/domain/repositories/` |
| 18 | **توحيد Earnings Helper** — 3 مسارات → مسار واحد | `WalletRepository` + `DriverProfileRepository` |
| 19 | **Bottom Nav labels** من `AppLocalizations` | `driver_home_screen.dart` |
| 20 | **عرض user_trip_stats** في User Profile | `UserProfileScreen` |

---

## ملحق — ملخص تدقيق سريع

```
التصحيحات في هذا الإصدار:
  ✅ admin_reply في Complaints → كان مطبقاً بالفعل
  ✅ Target Route / Corridor UI → كان مطبقاً بالفعل
  ✅ driver_bonus_ledger → كان مستخدماً بالفعل
  ⚠️ NotificationModel.titleAr → موجود في model، المشكلة في Screen فقط

أخطاء جديدة اكتُشفت:
  ❌ status='declined' → خطأ DB في reject
  ❌ FCM deep-link → Driver يُوجَّه لشاشة User
  ❌ Notifications tap → Driver يُوجَّه لـ userTripDetails
  ❌ Driver avatar edit button → ديكور بلا وظيفة
  ⚠️ UserWalletScreen → setState بدل WalletCubit
  ⚠️ Notifications → one-shot Future بدل Stream
  ⚠️ Driver home nav → نصوص Arabic hardcoded
  ⚠️ Searching → "سائق متاح" hardcoded
  ⚠️ 3 مسارات مختلفة لبيانات الأرباح
  ⚠️ set_driver_target_route RPC لا تُستدعى رغم وجود UI
```

---

*تم إعداد هذا التقرير بناءً على قراءة 184 ملف Dart و3007 سطر Schema بشكل كامل وتحليل تدفق البيانات.*
