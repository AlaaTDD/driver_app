---
name: Deep Investigation & Complete Fix
description: >
  يُفعَّل في كل مرة يُبلَّغ عن bug أو مشكلة أو طلب إصلاح.
  القاعدة الذهبية: X هو نقطة الدخول فقط — النطاق الحقيقي هو Feature كاملة.
priority: HIGHEST — يُطبَّق قبل أي إصلاح
---

# Deep Investigation & Complete Fix Protocol

> **القانون**: عندما يقول المستخدم "اصلح X" — X هو نقطة البداية، لا نهاية العمل.
> نطاقك هو الـ Feature كاملة في taxi_app + taxi_web.

---

## المرحلة 1: تحديد الـ Feature

| المستخدم يذكر... | الـ Feature |
|---|---|
| wallet, balance, top-up, withdrawal, earnings, payment, محفظة | **WALLET** |
| coupon, discount, promo, voucher, كوبون | **COUPONS** |
| trip, ride, fare, رحلة | **TRIPS** |
| tracking, map, live, تتبع حي | **TRACKING** |
| searching, بحث سائق, ride offer, bid | **SEARCHING/OFFER** |
| login, OTP, register, auth, session, blocked, تسجيل | **AUTH** |
| map, location, GPS, marker, route, خريطة | **MAP** |
| notification, push, FCM, إشعار | **NOTIFICATIONS** |
| rating, review, stars, تقييم | **RATINGS** |
| profile, name, phone, photo, vehicle, ملف شخصي | **PROFILE** |
| message, chat, complaint, رسالة, شكوى | **MESSAGES** |
| pricing, fare calculation, surge, night, تسعير | **PRICING** |
| bonus, incentive, reward, مكافأة | **BONUSES** |
| service area, zone, coverage, نطاق الخدمة | **SERVICE AREAS** |
| driver approval, revision, revoke, توثيق السائق | **DRIVER MANAGEMENT** |
| corridor, هيكل المسار | **CORRIDORS** |

---

## المرحلة 2: خريطة ملفات كل Feature

### WALLET
```
📱 taxi_app/lib/
├── features/wallet/data/models/
│   ├── driver_wallet_model.dart
│   ├── user_wallet_model.dart
│   ├── wallet_transaction_model.dart
│   └── withdrawal_request_model.dart
├── features/wallet/data/repositories/wallet_repository.dart
├── features/wallet/presentation/cubit/
│   ├── wallet_cubit.dart
│   └── user_wallet_cubit.dart
├── features/wallet/presentation/screens/
│   ├── driver_wallet_screen.dart   (46 KB)
│   └── user_wallet_screen.dart     (27 KB)
└── grep: grep -rn "wallet\|balance\|withdraw\|earning" lib/

🖥️ taxi_web/src/app/dashboard/wallets/ + withdrawals/
🖥️ taxi_web/src/app/api/wallets/ + withdrawals/
```

### TRACKING (رحلة حية)
```
📱 taxi_app/lib/
├── features/user/presentation/tracking/tracking_screen.dart   ~1400 سطر
├── features/user/presentation/tracking/bloc/tracking_bloc.dart
├── features/user/presentation/tracking/bloc/tracking_state.dart
├── core/services/cell_subscription_service.dart   # سائقون قريبون
├── core/services/trip_broadcast_service.dart     # بث التحديثات
├── core/map/ (كل ملفات الخريطة)
├── core/models/trip_details_model.dart
├── core/models/driver_profile_model.dart
└── grep: grep -rn "tracking\|TrackingBloc\|TrackingLoaded" lib/

⚠️ تحذير: TrackingLoaded يحمل Map<String, dynamic> — نمط خاطئ معروف
```

### TRIPS
```
📱 taxi_app/lib/
├── features/trips/data/models/trip_model.dart
├── features/trips/data/repositories/route_repository.dart
├── features/trips/domain/entities/trip_entity.dart
├── features/trips/presentation/bloc/trip_route_cubit.dart
├── features/trips/presentation/widgets/ (10 widgets)
├── features/driver/presentation/trip_details/trip_details_screen.dart  ~1800
├── features/driver/presentation/trips/driver_trips_screen.dart
├── features/user/presentation/trip_details/trip_details_screen.dart    ~1800
├── features/user/presentation/trips/trips_screen.dart
└── grep: grep -rn "trip\|ride\|fare\|TripModel" lib/

🖥️ taxi_web/src/app/dashboard/trips/ + trip-offers/
🖥️ taxi_web/src/app/api/trips/ + trip-offers/
```

### SEARCHING/OFFER
```
📱 taxi_app/lib/
├── features/user/presentation/searching/searching_screen.dart   ~800
├── features/user/presentation/searching/bloc/
├── features/driver/presentation/request_feed/driver_request_feed_screen.dart
├── features/driver/presentation/widgets/driver_offer_overlay.dart
├── core/models/trip_offer_model.dart
└── grep: grep -rn "offer\|bid\|searching\|SearchingBloc" lib/

🖥️ taxi_web/src/app/dashboard/trip-offers/
```

### AUTH
```
📱 taxi_app/lib/
├── features/auth/data/models/user_model.dart
├── features/auth/data/repositories/auth_repository_impl.dart  (13 KB)
├── features/auth/domain/entities/user_entity.dart
├── features/auth/domain/repositories/auth_repository.dart
├── features/auth/presentation/bloc/auth_bloc.dart
├── features/auth/presentation/screens/ (6 screens)
├── core/services/fcm_service.dart
├── core/services/logout_coordinator.dart
└── grep: grep -rn "auth\|login\|otp\|session\|token\|block" lib/

🖥️ taxi_web/src/app/login/ + lib/supabase/auth-guard.ts
```

### MAP
```
📱 taxi_app/lib/
├── core/map/ (builders + constants + controllers + factories + utils + widgets)
├── core/services/location_service.dart      (12 KB)
├── core/services/directions_service.dart
├── core/services/heatmap_service.dart
├── core/services/cell_subscription_service.dart
├── core/utils/geohash_helper.dart
├── core/utils/map_camera_utils.dart
└── grep: grep -rn "map\|location\|gps\|marker\|LatLng" lib/
```

### NOTIFICATIONS
```
📱 taxi_app/lib/
├── core/services/fcm_service.dart
├── core/models/notification_model.dart
├── features/shared/data/repositories/notifications_repository.dart
├── features/shared/presentation/notifications/notifications_screen.dart
└── grep: grep -rn "notification\|fcm\|push\|firebase_messaging" lib/

🖥️ taxi_web/src/app/dashboard/notifications/ + api/notifications/
```

### RATINGS
```
📱 taxi_app/lib/
├── features/shared/data/repositories/rating_repository.dart
├── features/shared/presentation/rating/bloc/
├── features/shared/presentation/rating/rating_screen.dart
└── grep: grep -rn "rating\|review\|star" lib/

🖥️ taxi_web/src/app/dashboard/ratings/ + api/ratings/
```

### PROFILE
```
📱 taxi_app/lib/
├── features/driver/presentation/profile/driver_profile_screen.dart    (25 KB)
├── features/driver/presentation/profile/bloc/
├── features/driver/data/repositories/driver_profile_repository.dart
├── features/user/presentation/profile/user_profile_screen.dart        (16 KB)
├── features/user/presentation/profile/bloc/
├── core/models/driver_profile_model.dart   (10 KB)
└── grep: grep -rn "profile\|vehicle\|photo\|document" lib/

🖥️ taxi_web/src/app/dashboard/drivers/ + users/
```

### MESSAGES
```
📱 taxi_app/lib/
├── features/shared/data/repositories/messages_repository.dart     (30 KB)
├── features/shared/data/repositories/complaints_repository.dart   (11 KB)
├── features/shared/presentation/messages/bloc/
├── features/shared/presentation/messages/screens/
├── features/shared/presentation/screens/complaints_screen.dart     (47 KB)
├── features/shared/presentation/chatbot/chatbot_screen.dart
├── core/models/conversation_model.dart, message_model.dart, complaint_model.dart
└── grep: grep -rn "message\|chat\|complaint\|conversation" lib/

🖥️ taxi_web/src/app/dashboard/messages/ + api/messages/
```

### PRICING
```
📱 taxi_app/lib/
├── features/user/presentation/pricing/pricing_screen.dart   (41 KB)
├── features/user/presentation/pricing/bloc/
├── features/user/presentation/pricing/pricing_args.dart
└── grep: grep -rn "pricing\|fare\|surge\|night_charge" lib/

🖥️ taxi_web/src/app/dashboard/pricing/ + api/pricing/
```

### BONUSES
```
📱 taxi_app/lib/
├── features/driver/presentation/bonus/bonus_screen.dart      (20 KB)
├── features/driver/presentation/bonus/bloc/
├── features/driver/data/repositories/bonus_repository.dart
├── core/models/bonus_rule_model.dart
├── core/models/bonus_progress_model.dart
└── grep: grep -rn "bonus\|incentive\|reward" lib/

🖥️ taxi_web/src/app/dashboard/bonuses/ + api/bonuses/
```

### CORRIDORS (Driver)
```
📱 taxi_app/lib/
├── features/driver/presentation/corridor/corridor_picker_screen.dart  (23 KB)
├── features/driver/presentation/corridor/bloc/
├── features/driver/data/repositories/corridor_repository.dart
└── grep: grep -rn "corridor\|CorridorBloc" lib/
```

### DRIVER HOME
```
📱 taxi_app/lib/
├── features/driver/presentation/home/driver_home_screen.dart    (26 KB)
├── features/driver/presentation/home/bloc/
├── features/driver/presentation/home/widgets/
├── features/driver/data/repositories/driver_home_repository.dart
├── features/driver/presentation/widgets/driver_offer_overlay.dart # ride offers
└── grep: grep -rn "DriverHome\|driverHome\|DriverBloc" lib/
```

---

## المرحلة 3: بروتوكول التدقيق

### Models
```
□ fromJson يعالج كل null (json['x'] as String? ليس as String)
□ num→double باستخدام (json['x'] as num?)?.toDouble()
□ DateTime.tryParse بدل DateTime.parse
□ toJson يشمل كل الحقول المطلوبة
□ يتطابق مع الـ schema الحالي في قاعدة البيانات
```

### Repository
```
□ select() محدد (لا select('*'))
□ Pagination على القوائم
□ try/catch + throw AppException
□ Filters صحيحة في Supabase queries
□ لا N+1 queries
□ Timeout (15s) على كل query
□ withRetry للعمليات الحرجة
```

### BLoC/Cubit
```
□ كل event handler فيه try/catch
□ emit(Loading) قبل العمل الـ async
□ emit(Error) في catch مع رسالة للمستخدم
□ Empty state مختلف عن Error state
□ لا emit بعد close()
□ Equatable في events وstates
□ buildWhen/listenWhen في widgets
□ لا Map<String, dynamic> في States
□ فحص tracking_state, searching_state, user_home_state
```

### Widget/Screen
```
□ Loading → AppLoadingState
□ Error → AppErrorState (icon + message + retry)
□ Empty → AppEmptyState
□ RefreshIndicator على القوائم
□ كل الألوان من AppColors/context
□ كل النصوص من AppLocalizations
□ الملف < 500 سطر
□ dispose() صحيح
□ mounted check بعد كل await
```

### API Routes (Next.js)
```
□ requireAdmin() أول شيء
□ zod schema validation ثاني شيء
□ try/catch حول كل database calls
□ logAdminAction للعمليات الحساسة
□ revalidatePath بعد mutations
```

---

## المرحلة 4: الإصلاح + Architecture

أثناء الإصلاح، اتبع **جميع** الـ Skills:
- `taxi-app-architecture` — بنية + imports + naming
- `premium-ui-standards` — ألوان + مسافات + حالات
- `flutter-performance` — const + ListView.builder + buildWhen
- `error-handling` — try/catch + AppException + null safety
- `supabase-database` — query optimization + joins + pagination

---

## المرحلة 5: التحقق

```bash
cd /Volumes/alaaMac/driverr/taxi/taxi_app
flutter analyze   # يجب: 0 errors, 0 warnings

# إذا كانت هناك تغييرات في Next.js:
cd /Volumes/alaaMac/driverr/taxi/taxi_web
npm run build    # يجب: نجاح الـ build
```

---

## المرحلة 6: تقرير كامل

```markdown
## 🔍 تقرير التحقيق — [Feature Name]

### المشكلة الأصلية
ما أبلغ عنه المستخدم

### النطاق المُحقَّق فيه
- X ملف في taxi_app
- Y ملف في taxi_web

### المشاكل المكتشفة والمُصلَحة
1. 🔴 [حرج] المشكلة الأصلية — ...
2. 🟡 [خطأ] مشكلة إضافية في... — ...
3. 🔵 [تنظيف] كود ميت — حُذف
4. ⚪ [أسلوب] لون hardcoded — استُبدل

### التحقق
- flutter analyze: ✅ 0 errors
```

---

## تذكيرات حديدية

1. لا تتوقف عند إصلاح المشكلة المُبلَّغ عنها فقط
2. دائماً ابحث في كلا المشروعين (taxi_app + taxi_web)
3. دائماً تحقق من: models, repositories, BLoCs, screens, API routes
4. دائماً شغّل `flutter analyze` بعد الإصلاح
5. دائماً اتبع الـ architecture skill أثناء الإصلاح
6. دائماً قدّم تقريراً بكل ما وجدته
