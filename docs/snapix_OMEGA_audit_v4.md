# تقرير المراجعة الشامل النهائي المطلق — Snapix Taxi
## Flutter + Supabase PostgreSQL — OMEGA Audit v4

> **الإصدار:** v4.0 OMEGA | **التاريخ:** 2026-05-16
> **يتجاوز:** كل التقارير السابقة (v1 + v2-Corrected + v3 + Ultimate)
> **المصادر:** 184 ملف Dart (قراءة سطر بسطر) + 3007 سطر Schema Introspection + CSV كامل
> **المشروع:** Snapix Taxi — Flutter + Supabase + Firebase FCM + Google Maps + Cloudflare R2
> **المنهج:** قراءة كل سطر كود + تحقق بـ grep + مقارنة DB ↔ Flutter + 6 اكتشافات جديدة لم يذكرها أي تقرير سابق

---

## 📋 فهرس المحتويات

| القسم | العنوان |
|-------|---------|
| 0 | الملخص التنفيذي |
| 1 | نظرة عامة + Tech Stack + إحصاءات |
| 2 | خريطة المعمارية الكاملة |
| 3 | الجرد الشامل — Routes, Models, Services, BLoC, DB |
| 4 | نقاط القوة المؤكدة بالكود |
| 5 | **[SEC] مشاكل الأمان — 4 مشاكل** |
| 6 | **[FL] أخطاء وظيفية Flutter — 10 مشاكل** |
| 7 | **[DB] مشاكل قاعدة البيانات — 9 مشاكل** |
| 8 | **[NEW] اكتشافات v4 الجديدة — 6 مشاكل لم تُذكر قط** |
| 9 | **[RT] أخطاء Runtime خفية — 2 مشاكل** |
| 10 | Dead Code المؤكد بـ grep |
| 11 | تعارضات DB ↔ Flutter |
| 12 | فرص إعادة الاستخدام |
| 13 | مصفوفة المخاطر الكاملة الموحّدة |
| 14 | خطة الإصلاح المرحلية |
| 15 | الملاحظات المعمارية النهائية |

---

## 0. الملخص التنفيذي

مشروع ناضج هيكلياً: 32 جدول، 87 وظيفة DB، RLS على 96.9%، 184 ملف Dart، BLoC منتظم في كل feature. المشروع في مرحلة pre-production (أقل من 200 رحلة، 27 MB DB).

### الحالة العامة

| الجانب | التقييم | التفاصيل |
|--------|---------|----------|
| بنية DB | ✅ ممتاز | RLS 31/32، 87 function، geohash indexing، pg_cron |
| كود Flutter | ⚠️ جيد مع مشاكل | BLoC منتظم، لكن runtime bugs خفية + 6 ثغرات جديدة |
| أمان | 🔴 4 ثغرات مؤكدة | SEC-01/02 حرجتان + 2 عاليتان |
| أداء DB | ⚠️ يحتاج تدخل فوري | Bloat + 21 جدول بدون ANALYZE |
| تراكم تقني | ⚠️ متوسط | Dead code + abstract layers فارغة + 6 مشاكل جديدة |

### أهم 10 مشاكل تستحق الإصلاح الفوري

| # | الأولوية | المشكلة |
|---|---------|---------|
| 1 | **🔴 P0-CRITICAL** | `cancel_trip` DB لا تتحقق من `p_cancelled_by = 'system'` → أي مستخدم يلغي أي رحلة |
| 2 | **🔴 P0-CRITICAL** | `SearchingBloc` يستغل الثغرة بـ `p_cancelled_by: 'system'` |
| 3 | **🔴 P0-HIGH** | `UserPresenceService.startBroadcasting()` يكتب (0,0) في DB عند كل login |
| 4 | **🔴 P0-HIGH** | `ComplaintsRepository` تُدرج `user_id = null` عند Session منتهية |
| 5 | **🆕 P0-HIGH** | `AuthBloc._onSignUpDriverRequested` لا يحفظ FCM Token → كل السائقين الجدد لا يتلقون FCM |
| 6 | **🆕 P1-HIGH** | `FCMService._handleMessageOpen` لـ `ride_offer` لا يفعل شيئاً → السائق يفتح التطبيق ولا يرى الرحلة |
| 7 | **🆕 P1-HIGH** | `HeatmapService` يستخدم Realtime مباشرة على `user_presence` — يناقض قرار الأمان المتعمد |
| 8 | **🟠 P1-HIGH** | 21 جدول بدون ANALYZE + 8 جداول Bloat 25-75% |
| 9 | **🆕 P2-MEDIUM** | `DirectionsService._cache` static لا يُنظَّف عند logout → route مؤقتة تتراكم |
| 10 | **🟠 P2-MEDIUM** | `TripOfferModel` ناقص `proposedPrice` → السائق لا يرى السعر المقترح |

---

## 1. نظرة عامة على المشروع

### Tech Stack

```
Frontend:    Flutter (Dart) — feature-based architecture
Backend:     Supabase (PostgreSQL 17.6 + Realtime + RPC + Storage)
Push:        Firebase Cloud Messaging (FCM)
Storage:     Cloudflare R2 (صور المستخدمين والمستندات)
Maps:        Google Maps Flutter + Google Directions API (مع cache محلي 5 دقائق)
Auth:        Supabase Auth
Realtime:    Polling كل 5 ثواني للـ Drivers (لأمان RLS) + Supabase Channels للمحادثات
             ⚠️ Realtime مباشر على user_presence في HeatmapService (inconsistency!)
State:       BLoC + Cubit
Router:      GoRouter مع UUID validation
Localization: ARB files (عربي/إنجليزي)
AI Chatbot:  Supabase Edge Function 'chatbot-ai' (OpenAI-compatible)
```

### إحصاءات المشروع

```
DB:      32 جدول | 87 function | 6 enums | 7 extensions | 27 MB
Flutter: 184 ملف | ~32 Screen | 20 BLoC/Cubit | 11 Service | 16 Repository
RLS:     96.9% (31/32 جدول) — الاستثناء: spatial_ref_sys (PostGIS system table)
Writes:  110,344 writes/session على user_presence (الأعلى) | trips: 314
Routes:  33 Route constant (مفقود: /driver/revision)
```

---

## 2. خريطة المعمارية الكاملة

```
lib/
├── main.dart                          # Entry point — Supabase, Firebase, FCM, Router
│                                      # ⚠️ 10 أسطر فارغة متتالية (كود محذوف غير منظّف)
├── firebase_options.dart
│
├── core/                              # Infrastructure مشتركة
│   ├── bloc_observer.dart
│   ├── constants/
│   │   ├── app_constants.dart         # Table names, activeTripStatuses, defaultMapCenter (Riyadh)
│   │   ├── app_routes.dart            # 33 Route constant (مفقود: driverRevision)
│   │   ├── env_constants.dart
│   │   └── map_styles.dart
│   ├── error/
│   │   └── error_mapper.dart          # 40+ error key → localized string
│   ├── models/                        # Shared models
│   │   ├── trip_offer_model.dart      # ⚠️ ناقص proposedPrice
│   │   ├── driver_profile_model.dart
│   │   ├── message_model.dart
│   │   ├── notification_model.dart
│   │   ├── rating_model.dart
│   │   ├── support_message_model.dart
│   │   ├── trip_route_plan_model.dart
│   │   ├── trip_route_waypoint_model.dart
│   │   ├── user_presence_model.dart
│   │   └── vehicle_type_model.dart
│   ├── repositories/
│   │   ├── app_config_repository.dart # Feature flags, maintenance mode (مع cache محلي)
│   │   └── driver_earnings_helper.dart
│   ├── router/
│   │   └── app_router.dart            # GoRouter — 33 route، UUID validation ✅
│   ├── services/
│   │   ├── connectivity_service.dart
│   │   └── location_permission_service.dart
│   ├── theme/                         # ThemeBloc, AppTheme, AppColors
│   ├── localization/                  # LanguageBloc, ARB عربي/إنجليزي
│   ├── utils/
│   │   ├── trip_status.dart           # TripStatus enum + canTransitionTo() ✅
│   │   ├── geohash_helper.dart
│   │   ├── uuid_helper.dart
│   │   ├── retry_helper.dart          # withRetry: Exponential Backoff ✅
│   │   └── app_toast.dart
│   ├── bloc/
│   │   └── location_permission_cubit.dart
│   └── widgets/                       # Shared widgets
│       ├── app_drawer.dart            # الـ Drawer الكامل (user+driver) — 452 سطر
│       ├── app_button.dart
│       ├── app_cached_image.dart
│       ├── bottom_sheet_container.dart
│       ├── custom_animated_bottom_nav.dart
│       ├── location_permission_cta.dart
│       ├── map_button.dart
│       └── stat_card.dart
│
├── services/                          # Global Singletons
│   ├── supabase_service.dart          # Supabase client wrapper
│   ├── location_service.dart          # GPS + fallback chain ✅ | ⚠️ startTripTracking void (NEW)
│   ├── cell_subscription_service.dart # Polling 5ث (قرار أمان متعمد) ✅
│   ├── user_presence_service.dart     # Heartbeat 60ث + Haversine 50m ✅ | ⚠️ يكتب (0,0)
│   ├── presence_service.dart          # Typing indicators للمحادثات ✅
│   ├── fcm_service.dart               # ⚠️ يستورد من presentation + ride_offer tap لا يفعل شيئاً (NEW)
│   ├── heatmap_service.dart           # ⚠️ Realtime مباشر على user_presence (NEW — inconsistency)
│   ├── r2_storage_service.dart        # Cloudflare R2 uploads
│   ├── trip_broadcast_service.dart    # → secure_broadcast_trip_offers RPC
│   └── directions_service.dart        # Google Directions API + cache ✅ | ⚠️ cache لا يُنظَّف (NEW)
│
└── features/
    ├── auth/
    │   ├── data/repositories/auth_repository_impl.dart  # Auto-recovery لـ PGRST116 ✅
    │   ├── domain/entities/ [UserEntity, DriverEntity]
    │   └── presentation/bloc/
    │       ├── auth_bloc.dart         # ⚠️ _onSignUpDriverRequested ناقص FCM + startBroadcasting (NEW)
    │       └── vehicle_types_cubit.dart
    │
    ├── user/
    │   ├── data/repositories/ [CouponRepository, MeetingPointRepository, TripsRepository]
    │   ├── domain/repositories/user_profile_repository.dart  # ⛔ ملف فارغ — احذف
    │   └── presentation/
    │       ├── home/ [UserHomeScreen + UserHomeBloc]
    │       ├── location_selection/ [LocationSelectionScreen + LocationBloc]
    │       ├── pricing/ [PricingScreen + PricingBloc]
    │       ├── meeting_point/ [MeetingPointScreen + MeetingBloc]
    │       ├── searching/ [SearchingScreen + SearchingBloc] # ⚠️ p_cancelled_by:'system'
    │       ├── tracking/ [TripTrackingScreen + TrackingBloc]
    │       ├── trips/ [UserTripsScreen + TripsBloc + widgets]
    │       ├── trip_details/ [UserTripDetailsScreen]
    │       └── profile/ [UserProfileScreen + ProfileBloc]
    │
    ├── driver/
    │   ├── data/repositories/ [DriverHomeRepository, DriverProfileRepository, BonusRepository, TripDetailsRepository]
    │   └── presentation/
    │       ├── home/ [DriverHomeScreen + DriverHomeBloc] # Smart throttle 5ث ✅
    │       ├── request_feed/ [DriverRequestFeedScreen]
    │       ├── profile/ [DriverProfileScreen + DriverProfileBloc]
    │       ├── trips/ [DriverTripsScreen + DriverTripsBloc]
    │       ├── trip_details/ [DriverTripDetailsScreen + TripDetailsBloc]
    │       ├── bonus/ [BonusScreen + BonusCubit]
    │       ├── widgets/ [driver_offer_overlay.dart]
    │       └── revision/  # ⛔ مجلد فارغ (+ route /driver/revision مفقود)
    │
    ├── shared/
    │   ├── data/repositories/ [MessagesRepository, RatingRepository, NotificationsRepository, ChatbotRepository, ComplaintsRepository]
    │   └── presentation/
    │       ├── messages/ [ConversationsScreen + MessagesScreen + MessagesCubit]
    │       ├── rating/ [RatingScreen + RatingBloc]
    │       ├── chatbot/ [ChatbotScreen] # ⚠️ بدون BLoC + prompt injection
    │       ├── notifications/ [NotificationsScreen] # ⚠️ بدون BLoC
    │       └── screens/ [PendingVerificationScreen + ComplaintsScreen] # ⚠️ admin_reply مفقود
    │
    ├── trips/
    │   ├── data/ [TripModel, RouteRepository]
    │   ├── domain/ [TripEntity, TripRepository] # ⛔ abstract بلا impl
    │   └── presentation/bloc/
    │       ├── trip_route_cubit.dart  # ✅ Optimistic Updates
    │       ├── trip_route_state.dart  # ✅
    │       ├── trip_event.dart        # ⛔ DEAD CODE مؤكد بـ grep
    │       └── trip_state.dart        # ⛔ DEAD CODE مؤكد بـ grep
    │
    ├── ride_offer/
    │   ├── bloc/ [RideOfferBloc]
    │   ├── data/models/ride_offer_model.dart  # ⚠️ مكرر مع TripOfferModel
    │   └── overlay/ride_offer_overlay.dart    # يستورده FCMService مباشرةً (انعكاس معماري)
    │
    └── wallet/
        ├── data/ [DriverWalletModel, UserWalletModel, WalletTransactionModel, WithdrawalRequestModel, WalletRepository]
        └── presentation/
            ├── cubit/wallet_cubit.dart        # ⚠️ يدعم Driver فقط
            └── screens/ [UserWalletScreen, DriverWalletScreen]
```

---

## 3. الجرد الشامل

### 3.1 — Routes (33 Route)

| Route | Screen | Scope |
|-------|--------|-------|
| `/splash` | SplashScreen | Shared |
| `/onboarding` | OnboardingScreen | Shared |
| `/login` | LoginScreen | Shared |
| `/register` | RegisterScreen | Shared |
| `/register/user` | RegisterUserScreen | User |
| `/register/driver` | RegisterDriverScreen | Driver |
| `/pending-verification` | PendingVerificationScreen | Driver |
| `/user/home` | UserHomeScreen | User |
| `/user/profile` | UserProfileScreen | User |
| `/user/trips` | UserTripsScreen | User |
| `/user/messages` | ConversationsScreen → MessagesScreen | User |
| `/user/chatbot` | ChatbotScreen | User |
| `/user/notifications` | NotificationsScreen | User |
| `/user/location-select` | LocationSelectionScreen | User |
| `/user/pricing` | PricingScreen | User |
| `/user/meeting-point` | MeetingPointScreen | User |
| `/user/searching` | SearchingScreen | User |
| `/user/tracking` | TripTrackingScreen | User |
| `/user/rating` | RatingScreen | User |
| `/user/trip-details` | UserTripDetailsScreen | User |
| `/user/complaints` | ComplaintsScreen | User |
| `/user/wallet` | UserWalletScreen | User |
| `/driver/home` | DriverHomeScreen | Driver |
| `/driver/profile` | DriverProfileScreen | Driver |
| `/driver/trips` | DriverTripsScreen | Driver |
| `/driver/messages` | ConversationsScreen → MessagesScreen | Driver |
| `/driver/chatbot` | ChatbotScreen | Driver |
| `/driver/notifications` | NotificationsScreen | Driver |
| `/driver/trip-details` | DriverTripDetailsScreen | Driver |
| `/driver/rating` | RatingScreen | Driver |
| `/driver/complaints` | ComplaintsScreen | Driver |
| `/driver/wallet` | DriverWalletScreen | Driver |
| `/driver/bonus` | BonusScreen | Driver |
| `/driver/request-feed` | DriverRequestFeedScreen | Driver |

**⚠️ مفقود:** `/driver/revision` رغم وجود جدول `driver_revision_requests` في DB + function `request_driver_revision`.

### 3.2 — BLoC / State Management (20+ وحدة)

| BLoC/Cubit | Feature | ملاحظة |
|-----------|---------|--------|
| AuthBloc | auth | ⚠️ _onSignUpDriverRequested ناقص FCM + presence (NEW) |
| VehicleTypesCubit | auth | |
| ThemeBloc | core | SharedPreferences |
| LanguageBloc | core | ARB + SharedPreferences |
| LocationPermissionCubit | core | |
| UserHomeBloc | user | يستخدم UserPresenceService |
| LocationBloc | user | DirectionsService |
| PricingBloc | user | CouponRepository |
| MeetingBloc | user | MeetingPointRepository |
| SearchingBloc | user | ⚠️ p_cancelled_by:'system' |
| TrackingBloc | user | UserPresenceService |
| TripsBloc | user | |
| ProfileBloc | user | |
| DriverHomeBloc | driver | Smart throttle 5ث ✅ |
| DriverProfileBloc | driver | |
| DriverTripsBloc | driver | |
| TripDetailsBloc | driver | |
| BonusCubit | driver | |
| MessagesCubit | shared | ⚠️ canSend دائماً true + _payloadSub وهمي |
| RatingBloc | shared | Dual-table rating ✅ |
| TripRouteCubit | trips | Optimistic Updates ✅ |
| RideOfferBloc | ride_offer | |
| WalletCubit | wallet | ⚠️ Driver فقط |

### 3.3 — Services (11 Singleton)

| Service | الغرض | ملاحظة |
|---------|-------|--------|
| SupabaseService | Client wrapper | |
| LocationService | GPS + fallback chain | ✅ مع ⚠️ startTripTracking void (NEW) |
| CellSubscriptionService | خريطة السائقين | Polling 5ث لأمان RLS ✅ |
| UserPresenceService | GPS presence + Heartbeat | ⚠️ يكتب (0,0) عند login |
| PresenceService | Typing indicators | ✅ مستخدم في MessagesCubit |
| FCMService | Push notifications | ⚠️ يستورد من presentation + ride_offer tap مكسور (NEW) |
| HeatmapService | خريطة كثافة المستخدمين | ⚠️ Realtime على user_presence (NEW) |
| R2StorageService | Cloudflare R2 uploads | |
| ConnectivityService | Network status | |
| TripBroadcastService | بث طلبات الرحلة | → secure_broadcast_trip_offers |
| DirectionsService | Google Directions API | ✅ مع cache | ⚠️ cache لا يُنظَّف (NEW) |

### 3.4 — جداول قاعدة البيانات (32 جدول)

#### Admin-only (خارج نطاق Flutter)

| الجدول | الغرض |
|-------|-------|
| `admin_logs` | سجل عمليات المشرفين |
| `driver_revision_requests` | ⚠️ موجود لكن لا Flutter UI |
| `driver_service_areas` | تعيين مناطق الخدمة |
| `coupon_audit_log` | تدقيق الكوبونات |

#### إحصاءات الكتابة (hot tables)

| الجدول | Total Writes | ملاحظة |
|-------|-------------|--------|
| `user_presence` | 110,344 | heartbeat كل 60ث |
| `drivers_profile` | 1,414 | أعلى update rate |
| `trips` | 314 | الأهم وظيفياً |
| `trip_offers` | 172 | |
| `messages` | 135 | |
| `users` | 116 | |

---

## 4. نقاط القوة المؤكدة بالكود

### DB Strengths

- **RLS 96.9%** — 31/32 جدول محمي (الاستثناء: spatial_ref_sys)
- **`validate_trip_status_transition`** — يمنع transitions غير قانونية server-side
- **`driver_accept_trip: FOR UPDATE SKIP LOCKED`** — يمنع race condition تماماً
- **`fn_credit_driver_earnings`** — حساب أرباح صحيح
- **`cleanup_stale_user_presence` (pg_cron)** — نظّفت 1,835 مرة تلقائياً ✅
- **Idempotency في `withdrawal_requests`**

### Flutter Strengths

- **BLoC منتظم** في كل feature تقريباً
- **`TripRouteCubit` Optimistic Updates** — يُضيف waypoint مؤقت قبل DB call، يتراجع عند الفشل
- **`MessagesCubit` Deduplication** — منطق ذكي لاستبدال optimistic message بالـ real عبر `content + senderId + id.length < 20`
- **`withRetry` Exponential Backoff** — مطبَّق على Presence upsert وعمليات حيوية
- **`CellSubscriptionService`** — polling آمن بدل Realtime (قرار مدروس)
- **`UserPresenceService` Haversine filter** — لا يكتب DB إذا الحركة أقل من 50 متر
- **`UserPresenceService` WidgetsBindingObserver** — يوقف heartbeat عند backgrounding تلقائياً
- **`DriverHomeBloc` Smart Throttle** — 5 ثوانٍ minimum بين location pushes
- **`LocationService` Fallback Chain** — GPS → lastKnownPosition → reduced accuracy
- **`AuthRepositoryImpl` Auto-Recovery** — إذا profile مفقود (PGRST116) ينشئه من auth metadata
- **`ErrorMapper`** — 40+ error key → localized string موحّد
- **`DirectionsService` Cache** — 50 مسار بـ TTL 5 دقائق + FIFO eviction صحيح
- **`AppConfigRepository`** — يُشغَّل في background عند startup بدون blocking

---

## 5. مشاكل الأمان [SEC]

---

### [SEC-01] 🔴 CRITICAL — cancel_trip: Authorization Bypass

**الأولوية: P0 — أصلح قبل أي نشر**

**الكود الحالي في DB:**
```sql
IF p_cancelled_by = 'user' AND trip_record.user_id != p_user_id THEN
  RAISE EXCEPTION 'User not authorized';
END IF;

IF p_cancelled_by = 'driver' AND trip_record.driver_id != p_user_id THEN
  RAISE EXCEPTION 'Driver not authorized';
END IF;
-- إذا p_cancelled_by = 'system' أو أي قيمة أخرى → لا فحص!
```

**الإصلاح:**
```sql
-- أضف في أول الدالة:
IF p_cancelled_by NOT IN ('user', 'driver', 'system') THEN
  RAISE EXCEPTION 'Invalid cancelled_by value: %', p_cancelled_by;
END IF;

IF p_cancelled_by = 'system' THEN
  IF trip_record.user_id != p_user_id THEN
    RAISE EXCEPTION 'System cancel only allowed by trip owner';
  END IF;
END IF;
```

---

### [SEC-02] 🔴 CRITICAL — SearchingBloc يستغل الثغرة بـ `p_cancelled_by: 'system'`

**الأولوية: P0 — مرتبط بـ SEC-01**

**الكود الحالي (searching_bloc.dart، دالة `_onTick`):**
```dart
// عند انتهاء 180 ثانية:
await withRetry(
  () => SupabaseService.client.rpc('cancel_trip', params: {
    'p_trip_id': tripId,
    'p_user_id': SupabaseService.currentUser!.id,
    'p_cancelled_by': 'system',  // ← يُتجاوز كل authorization checks
    'p_cancel_reason': 'timeout',
  }),
);
```

**لاحظ:** دالة `_onCancel` (الإلغاء اليدوي) تستخدم `'user'` بشكل صحيح ✅. المشكلة فقط في timeout.

**الإصلاح:**
```dart
'p_cancelled_by': 'user',  // المستخدم هو صاحب الرحلة في كل الأحوال
```

---

### [SEC-03] 🟠 HIGH — ComplaintsRepository: user_id قد يكون null

**الكود الحالي:**
```dart
final user = SupabaseService.currentUser;
await SupabaseService.client.from('complaints').insert({
  'user_id': user?.id,   // ← null إذا Session منتهية
  ...
});
```

**الإصلاح:**
```dart
final user = SupabaseService.currentUser;
if (user == null) throw Exception('errorNotLoggedIn');
await SupabaseService.client.from('complaints').insert({
  'user_id': user.id,  // مضمون
  ...
});
```

---

### [SEC-04] 🟠 HIGH — UserPresenceService يكتب (0,0) عند كل Login

**الكود الحالي:**
```dart
Future<void> startBroadcasting({double? lat, double? lng}) async {
  _lastLat = lat ?? _lastLat ?? 0.0;    // ← 0,0 إذا GPS غير متاح
  _lastLng = lng ?? _lastLng ?? 0.0;
  _isBroadcasting = true;
  await _upsertPresence(_lastLat!, _lastLng!, force: true);  // يكتب (0,0) فوراً
}
```

**الاستدعاء من AuthBloc (بدون lat/lng في كل مرة):**
```dart
await UserPresenceService.instance.startBroadcasting(); // → (0.0, 0.0) في DB
```

**الإصلاح:**
```dart
Future<void> startBroadcasting({double? lat, double? lng}) async {
  final resolvedLat = lat ?? _lastLat;
  final resolvedLng = lng ?? _lastLng;
  _isBroadcasting = true;

  if (resolvedLat == null || resolvedLng == null) {
    debugPrint('📡 UserPresence: Waiting for GPS — not writing to DB');
    return; // تكتب عند أول updateLocation()
  }

  _lastLat = resolvedLat;
  _lastLng = resolvedLng;
  await _upsertPresence(_lastLat!, _lastLng!, force: true);
}
```

---

## 6. أخطاء وظيفية Flutter [FL]

---

### [FL-01] 🔴 HIGH — TripOfferModel: proposedPrice مفقود

جدول `trip_offers` يحتوي على `proposed_price (numeric, nullable)` لكن `TripOfferModel` لا يضمّه.

**الإصلاح:**
```dart
class TripOfferModel extends Equatable {
  final double? proposedPrice;        // أضف
  // في fromJson:
  proposedPrice: (json['proposed_price'] as num?)?.toDouble(),
  // في props:
  proposedPrice,
}
```

---

### [FL-02] 🟠 HIGH — MessagesCubit.initTripChat: canSend دائماً true

**الكود:**
```dart
final active = AppConstants.activeTripStatuses.contains(status); // يُحسَب
// ...
canSend: true, // Always allow sending ← المتغير 'active' لا يُستخدم!
```

**الإصلاح:**
```dart
canSend: active,
```

---

### [FL-03] 🟡 MEDIUM — TripRouteCubit.addStopover يُصدر error عند النجاح

**الكود:**
```dart
final created = await _routeRepository.createRoutePlanFromLegacy(state.tripId!);
if (created == null) {
  emit(state.copyWith(status: TripRouteStatus.error, ...)); // error حقيقي ✅
  return;
}
// بعد النجاح:
emit(state.copyWith(
  status: TripRouteStatus.error,  // ← ERROR رغم النجاح!
  errorMessage: "Route plan initialized. Please try adding the stopover again.",
));
```

**الإصلاح:**
```dart
emit(state.copyWith(status: TripRouteStatus.loaded, errorMessage: null));
// يمكن استدعاء addStopover تلقائياً هنا
```

---

### [FL-04] 🟡 MEDIUM — DriverRevisionRequestsScreen مفقودة

`lib/features/driver/presentation/revision/` — مجلد فارغ. جدول `driver_revision_requests` موجود + function `request_driver_revision` + RLS. السائق لا يعرف أن الأدمن أرسل له طلب مراجعة.

---

### [FL-05] 🟡 MEDIUM — ComplaintsScreen: admin_reply لا تُعرض للمستخدم

`ComplaintsRepository` يجلب `status` فقط. جدول `complaints` يحتوي على `admin_reply`, `replied_at`, `priority`, `category` — المستخدم يرسل شكوى ولا يرى الرد أبداً.

---

### [FL-06] 🟡 MEDIUM — UserWalletScreen: State Management محلي غير قابل للاختبار

`WalletCubit` يدعم Driver فقط. `UserWalletScreen` تستخدم state محلي داخل الملف نفسه.

**الإصلاح:** توسيع `WalletCubit` أو إنشاء `UserWalletCubit` منفصل.

---

### [FL-07] 🟡 MEDIUM — FCMService: انعكاس معماري + Background Notification Gap

**الانعكاس المعماري:**
```dart
// fcm_service.dart (services/) يستورد من features/presentation/:
import '../features/ride_offer/overlay/ride_offer_overlay.dart';
```

**Background Gap:** `_firebaseMessagingBackgroundHandler` لا يفعل شيئاً سوى log — السائق الذي تصله رحلة خارج التطبيق لا يرى `RideOfferOverlay` أبداً.

**الإصلاح المعماري:**
```dart
class FCMService {
  Future<void> Function(Map<String, dynamic>)? _onRideOffer;
  void setRideOfferHandler(Future<void> Function(Map<String, dynamic>) h) => _onRideOffer = h;
}
// في DriverHomeScreen:
FCMService().setRideOfferHandler(handleRideOfferNotification);
```

---

### [FL-08] 🟡 MEDIUM — _broadcastedDriverIds يُملأ ولا يُقرأ

```dart
final Set<String> _broadcastedDriverIds = {}; // يُملأ بـ clear() فقط
// _performBroadcast لا تقرأه أبداً → يُرسل لكل السائقين كل 15 ثانية بدون استثناء
```

---

### [FL-09] 🟡 MEDIUM — FCMService._handledMessageIds: clear كلي عند 100

```dart
if (_handledMessageIds.length > 100) {
  _handledMessageIds.clear();  // يُصفَّر الكل → رسائل مكررة تمر بدون اكتشاف
}
```

**الإصلاح (FIFO):**
```dart
final _handledMessageIds = <String>[];
void _markHandled(String id) {
  if (_handledMessageIds.length >= 100) _handledMessageIds.removeAt(0);
  _handledMessageIds.add(id);
}
```

---

### [FL-10] 🟢 LOW — _payloadSub في MessagesCubit: يُعلَن ويُلغى ولا يُسنَد

```dart
StreamSubscription? _payloadSub;  // معرّف
await _payloadSub?.cancel();      // يُلغى في close()
// لا يوجد: _payloadSub = ...    ← لا يُسنَد أبداً
```

---

## 7. مشاكل قاعدة البيانات [DB]

---

### [DB-01] 🔴 HIGH — 21 جدول بدون ANALYZE

```sql
-- نفّذ فوراً:
ANALYZE admin_logs, app_config, bonus_rules, complaints, coupon_audit_log,
        coupon_usages, coupons, driver_bonus_ledger, driver_revision_requests,
        driver_service_areas, driver_wallets, pricing_config, ratings,
        service_areas, trip_route_plans, trip_route_waypoints,
        user_coupons, user_ratings, user_wallets, wallet_transactions,
        withdrawal_requests;
```

---

### [DB-02] 🔴 HIGH — Bloat: 8 جداول تحتاج VACUUM

| الجدول | Bloat % | Dead Rows | آخر autovacuum |
|-------|---------|-----------|----------------|
| `drivers_profile` | **75%** | 9 | 2026-05-16 ✅ |
| `vehicle_types` | **75%** | 12 | لا شيء ❌ |
| `users` | **65%** | 13 | لا شيء ❌ |
| `trip_route_waypoints` | **63.6%** | 14 | لا شيء ❌ |
| `driver_locations` | **60%** | 3 | 2026-05-05 ✅ |
| `driver_wallets` | **40%** | 2 | لا شيء ❌ |
| `trip_offers` | **32.2%** | 37 | 2026-05-03 ✅ |
| `trips` | **25.8%** | 32 | 2026-05-10 ✅ |

```sql
VACUUM ANALYZE users, vehicle_types, drivers_profile, trip_route_waypoints,
               driver_locations, driver_wallets, trip_offers, trips;
```

---

### [DB-03] 🟠 MEDIUM — ratings: UNIQUE Constraint خاطئ

`UNIQUE(trip_id, user_id)` بدلاً من `UNIQUE(trip_id)` — يسمح لمستخدمين مختلفين بتقييم نفس الرحلة.

```sql
-- تحقق أولاً:
SELECT trip_id, COUNT(*) FROM ratings GROUP BY trip_id HAVING COUNT(*) > 1;
-- إذا لا تكرارات:
ALTER TABLE ratings DROP CONSTRAINT IF EXISTS uq_ratings_trip_user;
ALTER TABLE ratings ADD CONSTRAINT uq_ratings_trip UNIQUE(trip_id);
```

---

### [DB-04] 🟠 MEDIUM — pricing_config: 0 rows

```sql
INSERT INTO pricing_config (vehicle_type, base_fare, price_per_km, minimum_fare)
SELECT name, base_fare, price_per_km, minimum_fare FROM vehicle_types
ON CONFLICT (vehicle_type) DO UPDATE SET
  base_fare = EXCLUDED.base_fare,
  price_per_km = EXCLUDED.price_per_km;
```

---

### [DB-05] 🟠 MEDIUM — driver_locations: مفقود index على geohash

`CellSubscriptionService` يفلتر بالـ geohash لكن `driver_locations` لا index عليها.

```sql
CREATE INDEX IF NOT EXISTS idx_driver_locations_geohash ON driver_locations(geohash);
```

---

### [DB-06] 🟠 MEDIUM — RLS Policies مكررة (5 حالات مؤكدة)

| الجدول | السياسات المكررة | الإجراء |
|-------|----------------|---------| 
| `user_ratings` | p_ur_insert + user_ratings_insert | احذف الأقدم |
| `user_ratings` | p_ur_select + user_ratings_select | احذف الأقدم |
| `user_presence` | p_up_select + user_presence_select | تحقق من USING ثم احذف |
| `user_presence` | p_up_write + user_presence_upsert_own | احذف الأقدم |
| `coupon_usages` | 3 SELECT policies لـ authenticated | احذف الزائد |

---

### [DB-07] 🟡 LOW — 23 Unused Index

كل الـ 23 index بها `idx_scan = 0`. لا تحذف الآن — انتظر 30 يوم traffic.

**استثناءان يُنصح بحذفهما فوراً:**
- `idx_trips_area` — على `service_area_id` 100% null
- `idx_trips_cancel_category` — على `cancel_reason_category` 100% null

---

### [DB-08] 🟡 LOW — أعمدة trips: 100% null

| العمود | السبب |
|-------|-------|
| `meeting_lat/lng/address` | Meeting point غير مكتملة |
| `scheduled_at` | Scheduled trips لم تُفعَّل |
| `cancel_reason_category` | لم يُربط بـ UI |
| `estimated_duration_min` | DirectionsService يحسبها ولا يحفظها |
| `service_area_id` | `fn_set_trip_service_area` موجود لكن لم يُفعَّل |

---

### [DB-09] 🟡 LOW — user_presence: 110,010 Updates

مع 1000 مستخدم نشط: ~17 write/ثانية. الحماية الحالية: Haversine 50m filter كافية حالياً. عند 5000+ مستخدم: فكر في exponential backoff للـ heartbeat.

---

## 8. اكتشافات v4 الجديدة [NEW] — لم تُذكر في أي تقرير سابق

---

### [NEW-01] 🔴 CRITICAL — AuthBloc._onSignUpDriverRequested: لا يحفظ FCM Token ولا يبدأ Presence

**الأولوية: P0 — كل سائق جديد يُسجَّل لا يتلقى FCM notifications حتى يُعيد تسجيل الدخول**

**الكود الحالي (auth_bloc.dart):**

```dart
// ✅ _onSignInRequested — يفعل كل شيء صح:
await result.fold(
  (error) async => emit(AuthError(error)),
  (user) async {
    await _storeFcmToken(user.id);          // ← يحفظ FCM ✅
    await UserPresenceService.instance.startBroadcasting(); // ← يبدأ Presence ✅
    emit(AuthAuthenticated(user));
  },
);

// ✅ _onSignUpUserRequested — يفعل كل شيء صح:
await result.fold(
  (error) async => emit(AuthError(error)),
  (user) async {
    await _storeFcmToken(user.id);          // ← يحفظ FCM ✅
    await UserPresenceService.instance.startBroadcasting(); // ← يبدأ Presence ✅
    emit(AuthAuthenticated(user));
  },
);

// 🔴 _onSignUpDriverRequested — ناقص:
result.fold(
  (error) => emit(AuthError(error)),
  (user) => emit(AuthDriverPending(user)),   // ← لا FCM ❌ لا Presence ❌
);
```

**الأثر المزدوج:**

1. **FCM مفقود:** السائق الجديد لن يتلقى أي إشعار FCM — لا رحلات جديدة، لا رسائل — حتى يُعيد تسجيل الدخول يدوياً.

2. **Presence غير مبدأ:** رغم أن AuthDriverPending يذهب لـ PendingVerificationScreen ولا يحتاج presence، هذه المشكلة تظهر لاحقاً إذا أُضيفت منطق جديد.

**الإصلاح:**
```dart
Future<void> _onSignUpDriverRequested(
  SignUpDriverRequested event,
  Emitter<AuthState> emit,
) async {
  // ...
  await result.fold(
    (error) async => emit(AuthError(error)),
    (user) async {
      await _storeFcmToken(user.id);  // ← أضف هذا
      // لا startBroadcasting هنا (السائق غير verified بعد)
      emit(AuthDriverPending(user));
    },
  );
}
```

---

### [NEW-02] 🔴 HIGH — FCMService._handleMessageOpen: 'ride_offer' لا يُنجز أي action

**الأولوية: P1 — كل سائق يفتح التطبيق من notification لا يرى الرحلة**

**الكود الحالي:**
```dart
Future<void> _handleMessageOpen(RemoteMessage message) async {
  final type = message.data['type'] ?? message.data['notification_type'];
  // ...
  switch (type) {
    case 'new_message':
      // يُوجِّه للرسائل ✅
      break;
    case 'trip':
      // يُوجِّه لتفاصيل الرحلة ✅
      break;
    case 'ride_offer':
      developer.log('🔥 FCM OPENED APP: User tapped ride_offer notification!');
      // Typically you'd navigate to the trip details page here.
      // ← لا يفعل شيئاً! السائق يفتح التطبيق ويجد نفسه في DriverHomeScreen الفارغة
      break;
  }
}
```

**السيناريو المكسور:**
1. السائق يتلقى notification "رحلة جديدة" وهو خارج التطبيق
2. يضغط على الـ notification
3. التطبيق يفتح
4. لا شيء يحدث — السائق يجد نفسه في الشاشة الأخيرة التي كان فيها
5. إذا انتهت مهلة العرض (15-30 ثانية) أثناء فتح التطبيق، يفوته الطلب نهائياً

**الإصلاح:**
```dart
case 'ride_offer':
  final tripId = message.data['trip_id'] ?? message.data['tripId'];
  final router = AppRouter.routerInstance;
  // Navigate to driver home (which will show the offer via RideOfferBloc stream)
  router.go(AppRoutes.driverHome);
  // Or navigate directly to trip details if tripId is available:
  if (tripId != null) {
    router.go('${AppRoutes.driverTripDetails}?tripId=$tripId');
  }
  break;
```

---

### [NEW-03] 🟠 HIGH — HeatmapService: Realtime مباشر على user_presence يناقض قرار الأمان المتعمد

**الأولوية: P2 — inconsistency أمنية مع معمارية مدروسة**

**القرار المتعمد في CellSubscriptionService:**
```dart
// cell_subscription_service.dart:
// "Instead of subscribing to Realtime which requires permissive RLS
//  (and exposes national_id), we poll the secure RPC every 5 seconds."
```

**لكن HeatmapService تفعل العكس:**
```dart
// heatmap_service.dart:
void _subscribeToRealtime() {
  _realtimeChannel = SupabaseService.client.channel('heatmap-presence');
  _realtimeChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_presence',      // ← Realtime مباشر على جدول حساس
        callback: (payload) => _handlePresenceChange(payload),
      )
      .subscribe(...);
}
```

**لماذا هذا مشكلة:**
- `user_presence` يحتوي على `lat/lng` لكل المستخدمين النشطين
- إذا كان RLS على Realtime أقل صرامة من RLS على SELECT، يمكن أن يتلقى المستخدم تحديثات مواقع مستخدمين لا يجب له رؤيتهم
- المنطق الحالي (فلترة `myId` على الـ payload) يعتمد على client-side filtering، وهذا ليس ضماناً كافياً إذا كان Realtime يبث كل الصفوف

**التوصية:**
- مراجعة `user_presence` Realtime policy في Supabase Dashboard
- إذا كان الـ policy مقيّداً بشكل صحيح: وثّق القرار في الكود
- إذا لم يكن: استبدل بـ polling مثل `CellSubscriptionService`:

```dart
// بدل Realtime:
Timer.periodic(const Duration(seconds: 30), (_) => _fetchAllPresence());
```

---

### [NEW-04] 🟠 MEDIUM — DirectionsService._cache لا يُنظَّف عند logout

**الأولوية: P2 — stale routes قد تظهر لمستخدم مختلف**

**المشكلة:**
```dart
// directions_service.dart:
static final Map<String, _CachedResult> _cache = {}; // static — يبقى بين sessions

static void clearCache() => _cache.clear(); // موجود لكن لا أحد يستدعيه عند logout!
```

**فحص استخدام `clearCache`:**
```
grep -rn "clearCache" lib/ → لا استدعاء من AuthBloc أو أي مكان آخر
```

**أثر الـ TTL؟** 5 دقائق فقط — لكن المشكلة الأعمق: المسارات المحفوظة خاصة بالمستخدم ومكان طلبه. إذا سجّل مستخدم جديد على نفس الجهاز خلال 5 دقائق، سيرى مسارات الجلسة السابقة.

**الإصلاح — في AuthBloc._onSignOutRequested:**
```dart
Future<void> _onSignOutRequested(...) async {
  await UserPresenceService.instance.stopBroadcasting();
  await CellSubscriptionService.instance.dispose();
  HeatmapService.instance.dispose();
  LocationService.instance.stopAllTracking();
  DirectionsService.clearCache();  // ← أضف هذا
  final result = await _authRepository.signOut();
  // ...
}
```

---

### [NEW-05] 🟠 MEDIUM — LocationService.startTripTracking: void + unawaited future يأكل الأخطاء

**الأولوية: P2 — فشل GPS الأولي يمر بصمت**

**الكود الحالي:**
```dart
// الدالة void (ليست async):
void startTripTracking(String driverId) {
  // ...
  // fire-and-forget بالكامل:
  getCurrentLocation().then((pos) {
    if (_lastLat == null) {
      _lastLat = pos.latitude;
      // تحديث drivers_profile...
      SupabaseService.client.from('drivers_profile').update({
        'current_lat': pos.latitude,
        // ...
      }).eq('id', driverId); // ← هذه أيضاً unawaited داخل then!
    }
  }).catchError((_) {});  // ← كل الأخطاء تُبتلع صامتاً
}
```

**مشاكل محددة:**

1. **`void` بدل `Future<void>`**: الاستدعاء لا يمكن `await` عليه — لا يعرف أحد متى انتهى الـ initialization.

2. **`catchError((_) {})`**: إذا فشل `getCurrentLocation()` (GPS معطّل)، تبقى `drivers_profile` بدون تحديث مبدئي، والخريطة تُظهر السائق في موقع قديم.

3. **`.update({...}).eq('id', driverId)` داخل `then` غير مُنتظر**: إذا فشل الـ update، لا أحد يعرف.

**الإصلاح:**
```dart
Future<void> startTripTracking(String driverId) async {
  // ...
  try {
    final pos = await getCurrentLocation();
    if (_lastLat == null) {
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      _lastHeading = pos.heading;
      await SupabaseService.client.from('drivers_profile').update({
        'current_lat': pos.latitude,
        'current_lng': pos.longitude,
        // ...
      }).eq('id', driverId);
    }
  } catch (e) {
    debugPrint('⚠️ LocationService.startTripTracking: Initial GPS fix failed: $e');
    // لا تُبتلع — سجّل على الأقل
  }
}
```

---

### [NEW-06] 🟡 MEDIUM — FCMService._showLocalNotification: notification.hashCode كـ ID يُسبب تغطية صامتة

**الأولوية: P3 — إشعارات قد تُخفى بدون رؤيتها**

**الكود الحالي:**
```dart
await _localNotifications.show(
  notification.hashCode,  // ← مشكلة
  notification.title,
  notification.body,
  details,
);
```

**المشكلة:**
- `flutter_local_notifications` يستخدم الـ ID لتعريف الإشعار. إذا جاء إشعاران بنفس الـ `hashCode`، الثاني يُحل محل الأول بدلاً من أن يُضاف
- في Dart، `RemoteNotification.hashCode` ليس مضموناً أن يكون فريداً — إذا كان `title + body` متطابقَين (مثل: "رحلة جديدة" متكررة)، ستُلغى إشعارات حقيقية صامتاً

**الإصلاح:**
```dart
// استخدم ID عشوائي أو counter:
int _notificationCounter = 0;

await _localNotifications.show(
  _notificationCounter++,  // دائماً فريد
  notification.title,
  notification.body,
  details,
);
// أو: استخدم hashCode للـ messageId وليس للـ notification object
```

---

## 9. أخطاء Runtime خفية [RT]

---

### [RT-01] 🟠 MEDIUM — WalletRepository: wallet_id = userId قد يفشل للسائقين

```dart
.from('wallet_transactions')
.select()
.eq('wallet_id', userId)  // يعمل لـ user_wallets (id = user_id)
// لكن إذا driver_wallets.id ≠ driver_id → سجلات فارغة صامتة
```

**التحقق:**
```sql
SELECT id, driver_id FROM driver_wallets LIMIT 5;
-- إذا id ≠ driver_id: يلزم JOIN
```

---

### [RT-02] 🟡 MEDIUM — PresenceService Race Condition

```dart
startPresence(channelKey);    // channel موجود لكن غير subscribed بعد
_presenceService.onSync(cb);  // subscribe يحدث هنا

// إذا updateTyping() استُدعي بين الاثنتين:
// _channel موجود لكن unsubscribed → فشل صامت
```

الاحتمالية منخفضة في الاستخدام الحالي لكن تُعرّضها للفشل مستقبلاً.

---

## 10. Dead Code المؤكد بـ grep

| الملف | الدليل | الإجراء |
|-------|-------|--------|
| `trip_event.dart` | `grep -rn "TripEvent\|trip_event" lib/` → صفر imports | احذف |
| `trip_state.dart` | `grep -rn "TripState\|trip_state" lib/` → صفر imports | احذف |
| `user_drawer.dart` | `grep -rn "UserDrawer\|user_drawer" lib/` → تعريف فقط | احذف |
| `user_profile_repository.dart` | محتواه comment فقط | احذف |

---

## 11. تعارضات DB ↔ Flutter

| ID | DB | Flutter | الأثر | الأولوية |
|----|-----|---------|-------|---------|
| **MM-01** | `trip_offers.proposed_price` | غير موجود في TripOfferModel | السائق لا يرى السعر المقترح | P1 |
| **MM-02** | `trips` لا يحتوي `passenger_name` | RideOfferModel يقرأ `json['passenger_name']` | الاسم يظهر فقط إذا query تضم join | P2 |
| **MM-03** | `trips.status: in_progress` | `TripStatus.inProgress.toDbString() = 'in_progress'` | ✅ لا تعارض |  |
| **MM-04** | `wallet_transaction_type` لا يحتوي `trip_fare` | WalletTransactionModel يُحوّل `'trip_fare'` → `tripEarning` | ربما legacy — تحقق | P3 |
| **MM-05** | `driver_earnings_summary` view تُعيد `available_balance` | `DriverWalletModel.fromJson` يقبل كليهما | ✅ يعمل — وثّقه | |
| **MM-06** | `users.avatar_url` 100% null | ProfileBloc يعرضه | لا صور تُعرض حالياً | P3 |
| **MM-07** | `complaints.user_id` nullable FK | ComplaintsRepository تمرر `user?.id` | ⚠️ إدخال null محتمل | P0 |

---

## 12. فرص إعادة الاستخدام

### [R-01] AppDrawer — توحيد كامل
`AppDrawer` (core/widgets/) هو المُستخدم. `UserDrawer` dead code. احذفه.

### [R-02] SharedTripCard
`TripCard` في `user/presentation/trips/widgets/` — وسّعه بـ `isDriver` param.

### [R-03] AppEmptyState + AppErrorState
8+ شاشات تبني empty/error state بشكل مختلف. استخرج كـ shared widgets.

### [R-04] Map Widget موحّد
5 شاشات تبني Google Map باستقلالية (UserHomeScreen, SearchingScreen, TripTrackingScreen, MeetingPointScreen, DriverHomeScreen). Risk: Medium — أجّل بعد استقرار الـ features.

---

## 13. مصفوفة المخاطر الكاملة الموحّدة

| ID | الأولوية | المشكلة | الخطورة | الجهد | الأثر إذا أُهمل |
|----|---------|---------|---------|-------|----------------|
| SEC-01 | **P0** | cancel_trip auth bypass في DB | CRITICAL | دقائق | أي مستخدم يلغي أي رحلة |
| SEC-02 | **P0** | SearchingBloc يستخدم 'system' | CRITICAL | دقائق | استغلال SEC-01 |
| **NEW-01** | **P0** | AuthBloc: SignUpDriver بدون FCM token | HIGH | 10 دقائق | كل سائق جديد لا يتلقى FCM |
| SEC-03 | **P0** | complaints.user_id = null | HIGH | دقيقة | orphan records |
| SEC-04 | **P0** | UserPresence يكتب (0,0) | HIGH | 15 دقيقة | بيانات موقع خاطئة في DB |
| DB-01 | **P0** | 21 جدول بدون ANALYZE | HIGH | دقيقة | query planner أعمى |
| DB-02 | **P0** | Bloat 25-75% على 8 جداول | HIGH | دقائق | أداء متدهور |
| **NEW-02** | **P1** | FCMService: ride_offer tap لا يفعل شيئاً | HIGH | 30 دقيقة | سائق يفتح التطبيق ولا يرى الرحلة |
| FL-01 | **P1** | TripOfferModel ناقص proposedPrice | HIGH | 30 دقيقة | السائق لا يرى السعر المقترح |
| FL-02 | **P1** | canSend دائماً true في trip chat | HIGH | دقائق | رسائل في رحلات منتهية |
| FL-07 | **P1** | FCMService → RideOfferOverlay inversion | HIGH | يوم | Background rides ضائعة |
| **NEW-03** | **P2** | HeatmapService: Realtime inconsistency | MEDIUM | ساعة | خطر أمان محتمل |
| **NEW-04** | **P2** | DirectionsService.cache لا يُنظَّف | MEDIUM | 5 دقائق | stale routes بين sessions |
| **NEW-05** | **P2** | LocationService.startTripTracking void | MEDIUM | ساعة | فشل GPS صامت |
| DB-03 | **P1** | ratings UNIQUE constraint خاطئ | MEDIUM | ساعة | تقييمات مكررة |
| DB-04 | **P1** | pricing_config فارغة | MEDIUM | 15 دقيقة | PricingBloc يعرض فارغ |
| FL-05 | **P1** | ComplaintsScreen: admin_reply مفقود | MEDIUM | ساعة | المستخدم لا يرى الرد |
| FL-03 | **P2** | addStopover يُرسل error عند النجاح | HIGH | 30 دقيقة | UX مكسور |
| FL-08 | **P2** | _broadcastedDriverIds لا يُقرأ | MEDIUM | ساعة | rebroadcast غير مفلتر |
| FL-09 | **P2** | _handledMessageIds clear كلي | MEDIUM | ساعة | duplicate FCM messages |
| DB-05 | **P2** | Missing geohash index على driver_locations | MEDIUM | دقيقة | Realtime بطيء عند النمو |
| FL-04 | **P2** | DriverRevisionRequestsScreen مفقودة | MEDIUM | يومان | السائق لا يرى المراجعات |
| DB-06 | **P2** | 5 RLS policies مكررة | LOW | ساعة | overhead مضاعف |
| DC-01 | **P2** | Dead code: trip_event/state/UserDrawer | LOW | 30 دقيقة | تراكم تقني |
| RT-01 | **P2** | wallet_id vs userId في transactions | MEDIUM | ساعة | سجلات فارغة صامتة |
| **NEW-06** | **P3** | notification.hashCode collision | LOW | 15 دقيقة | إشعارات تُلغي بعضها |
| FL-10 | **P3** | _payloadSub وهمي | LOW | ساعة | feature ناقصة |
| FL-06 | **P3** | UserWalletScreen بدون Cubit | MEDIUM | يوم | state loss عند rebuild |
| RT-02 | **P3** | PresenceService race condition | LOW | ساعة | typing indicator يفشل صامتاً |
| DB-07 | **P4** | 23 unused indexes | LOW | انتظر 30 يوم | write overhead بسيط |

---

## 14. خطة الإصلاح المرحلية

### المرحلة 0 — P0: أمان وبيانات (ابدأ الآن، لا تؤخر — يوم واحد)

**DB (دقائق):**
```sql
-- 1. إصلاح cancel_trip (الأهم):
IF p_cancelled_by NOT IN ('user', 'driver', 'system') THEN
  RAISE EXCEPTION 'Invalid cancelled_by value: %', p_cancelled_by;
END IF;
IF p_cancelled_by = 'system' AND trip_record.user_id != p_user_id THEN
  RAISE EXCEPTION 'System cancel only allowed by trip owner';
END IF;

-- 2. ANALYZE على 21 جدول:
ANALYZE admin_logs, app_config, bonus_rules, complaints, coupon_audit_log,
        coupon_usages, coupons, driver_bonus_ledger, driver_revision_requests,
        driver_service_areas, driver_wallets, pricing_config, ratings,
        service_areas, trip_route_plans, trip_route_waypoints,
        user_coupons, user_ratings, user_wallets, wallet_transactions,
        withdrawal_requests;

-- 3. VACUUM ANALYZE:
VACUUM ANALYZE users, vehicle_types, drivers_profile, trip_route_waypoints,
               driver_locations, driver_wallets, trip_offers, trips;
```

**Flutter (ساعة):**
```dart
// 4. searching_bloc.dart:
'p_cancelled_by': 'user', // بدل 'system'

// 5. complaints_repository.dart:
if (user == null) throw Exception('errorNotLoggedIn');

// 6. user_presence_service.dart:
if (resolvedLat == null || resolvedLng == null) { _isBroadcasting = true; return; }

// 7. auth_bloc.dart — _onSignUpDriverRequested:
await _storeFcmToken(user.id); // أضف قبل emit(AuthDriverPending)
```

---

### المرحلة 1 — P1: Bugs وظيفية (الأسبوع الأول)

| # | المهمة | الملف | وقت |
|---|--------|-------|-----|
| 1 | FCMService._handleMessageOpen: أضف navigation لـ ride_offer | `fcm_service.dart` | 30 دقيقة |
| 2 | TripOfferModel: أضف proposedPrice | `trip_offer_model.dart` | 30 دقيقة |
| 3 | MessagesCubit: `canSend: active` بدل `true` | `messages_cubit.dart` | دقائق |
| 4 | pricing_config: تعبئة من vehicle_types | DB | 15 دقيقة |
| 5 | ratings UNIQUE constraint | DB | ساعة |
| 6 | ComplaintsRepository: جلب admin_reply | `complaints_repository.dart` | ساعة |

---

### المرحلة 2 — P2: تنظيف وتحسين (الأسبوع 2-3)

| # | المهمة | الملف | وقت |
|---|--------|-------|-----|
| 7 | HeatmapService: مراجعة Realtime RLS أو استبدال بـ polling | `heatmap_service.dart` | ساعة |
| 8 | DirectionsService: `clearCache()` عند logout في AuthBloc | `auth_bloc.dart` | 5 دقائق |
| 9 | LocationService.startTripTracking: تحويل لـ Future<void> | `location_service.dart` | ساعة |
| 10 | TripRouteCubit.addStopover: إصلاح emit error عند النجاح | `trip_route_cubit.dart` | 30 دقيقة |
| 11 | _broadcastedDriverIds: طبّق الفلترة أو احذف | `searching_bloc.dart` | ساعة |
| 12 | _handledMessageIds: استبدال بـ FIFO | `fcm_service.dart` | ساعة |
| 13 | Dead Code: احذف trip_event/state/UserDrawer/user_profile_repository | Flutter | 30 دقيقة |
| 14 | CREATE INDEX على driver_locations.geohash | DB | دقيقة |
| 15 | حذف 5 RLS policies مكررة | DB | ساعة |
| 16 | DriverRevisionRequestsScreen | Flutter | يومان |
| 17 | تحقق من wallet_id vs userId | DB + Flutter | ساعة |

---

### المرحلة 3 — P3: معمارة (الأسبوع 4+)

| # | المهمة | وقت |
|---|--------|-----|
| 18 | FCMService: Callback pattern بدل import من presentation | يوم |
| 19 | notification.hashCode: استبدل بـ counter | 15 دقيقة |
| 20 | UserWalletCubit: توسيع WalletCubit | يوم |
| 21 | _payloadSub: احذف أو ربط بـ subscription حقيقي | ساعة |
| 22 | قرار معماري: TripRepository impl أو حذف | يوم |
| 23 | RideOfferModel + TripOfferModel: توحيد — لا تفعل بدون tests! | يومان |

---

### المرحلة 4 — P4: بعد Traffic حقيقي (30+ يوم من Launch)

| # | المهمة |
|---|--------|
| 24 | مراجعة 23 unused index بعد traffic |
| 25 | `autovacuum_vacuum_scale_factor = 0.05` على trips و drivers_profile |
| 26 | مراجعة UserPresence heartbeat interval عند 1000+ مستخدم |
| 27 | تقييم DirectionsService cache size (50 → 100 مسار عند النمو) |

---

## 15. الملاحظات المعمارية النهائية

### ما لا تفعله الآن

- **لا تدمج RideOfferModel + TripOfferModel** — يمس FCMService + DriverHomeScreen + DriverRequestFeedScreen + DriverOfferOverlay في آن واحد
- **لا تحذف RLS policies دفعةً واحدة** — كل policy تحتاج `SELECT policyname, qual FROM pg_policies WHERE tablename = '...'` قبل الحذف
- **لا تبني TripRepositoryImpl** قبل اتخاذ قرار معماري
- **لا تحذف الـ 21 unused index قبل 30 يوم traffic**

### القرار المعماري الأهم

**الخيار أ — Clean Architecture كاملة:**
- إكمال domain layer لكل feature
- الوقت: 2-3 أسابيع | الفائدة: testability كاملة

**الخيار ب — Service-Repository (الأسرع الآن):**
- حذف الـ abstract layers الفارغة
- الوقت: 3 أيام | الفائدة: وضوح معماري فوري

**التوصية للمرحلة الحالية (pre-production):** الخيار ب.

### الملاحظة الكاملة حول CellSubscriptionService vs HeatmapService

هناك تناقض معماري واضح:

```
CellSubscriptionService: "بدل Realtime الذي يحتاج RLS أقل صرامة ويكشف national_id،
                          نستخدم polling آمن على RPC كل 5 ثواني" ← قرار ذكي ✅

HeatmapService: يستخدم onPostgresChanges مباشرة على user_presence ← تناقض ⚠️
```

الفرق: `user_presence` لا يحتوي `national_id`، لذا الخطر أقل. لكن يجب توثيق هذا القرار صراحةً في الكود لتجنب الإرباك، أو استخدام polling للاتساق.

### CellSubscriptionService — سبب Polling وليس Realtime (موثّق صراحةً)

```dart
// بدلاً من subscribing to Realtime الذي يحتاج RLS أقل صرامة
// (وقد يكشف national_id للسائقين)،
// نستخدم polling على RPC آمن كل 5 ثوانٍ.
```

قرار صحيح. لا تُغيّره بدون تقييم RLS على `driver_locations`.

### 87 DB Function — التوزيع الكامل

```
Public RPCs (Flutter يستدعيها):   ~25 function
  - cancel_trip, driver_accept_trip, user_accept_offer
  - set_driver_online, set_driver_offline, upsert_driver_location
  - get_nearby_drivers_secure, secure_broadcast_trip_offers
  - apply_coupon, create_driver_account, driver_complete_trip
  - get_driver_bonus_summary, validate_withdrawal_request... إلخ

Trigger functions (internal):     ~20 function
  - validate_trip_status_transition (server-side guard ✅)
  - fn_credit_driver_earnings
  - _fn_sync_pricing_from_vehicle_types
  - set_final_price_on_complete... إلخ

Admin-only functions:             ~40 function
  - block_user, unblock_user, verify_driver, approve_withdrawal
  - get_admin_dashboard_stats, log_admin_action... إلخ

pg_cron scheduled jobs:
  - cleanup_stale_user_presence (كل دقيقة) — نظّفت 1,835 مرة ✅
  - cleanup_orphan_trip_offers
  - cleanup_stale_trips
  - expire_trip_offers
```

---

## ملخص الاكتشافات الجديدة لـ v4 (غير موجودة في أي تقرير سابق)

| ID | المشكلة | الخطورة | الملف |
|----|---------|---------|-------|
| **NEW-01** | AuthBloc._onSignUpDriverRequested لا يحفظ FCM Token | 🔴 CRITICAL | `auth_bloc.dart` |
| **NEW-02** | FCMService._handleMessageOpen لـ ride_offer لا يُنجز navigation | 🔴 HIGH | `fcm_service.dart` |
| **NEW-03** | HeatmapService يستخدم Realtime مباشر — inconsistency مع قرار الأمان | 🟠 HIGH | `heatmap_service.dart` |
| **NEW-04** | DirectionsService._cache لا يُنظَّف عند logout | 🟠 MEDIUM | `auth_bloc.dart` |
| **NEW-05** | LocationService.startTripTracking: void + unawaited + silent failure | 🟠 MEDIUM | `location_service.dart` |
| **NEW-06** | notification.hashCode collision risk في FCMService | 🟡 LOW | `fcm_service.dart` |

---

*نهاية التقرير الشامل النهائي المطلق — OMEGA Audit v4*

*المصادر: 184 ملف Dart (قراءة سطر بسطر بـ grep وتحليل) + 3007 سطر Schema Introspection + CSV كامل*
*يتجاوز: v1 (Architecture + Inventory) + v2-Corrected (Code Audit) + v3 (Runtime Bugs) + Ultimate (Unified)*
*الإضافات الحصرية لـ v4: 6 اكتشافات جديدة مؤكدة بالكود الفعلي*
*التاريخ: 2026-05-16*
