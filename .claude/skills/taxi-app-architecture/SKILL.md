---
name: Taxi App Architecture
description: >
  الـ MASTER SKILL — يُقرأ قبل أي كود Dart/Flutter بدون استثناء.
  يفعّل عند: كتابة/تعديل أي ملف في lib/، إنشاء widget أو BLoC أو
  Repository أو Model أو Service، إضافة feature جديدة، أو أي سؤال عن بنية المشروع.
priority: CRITICAL — يُقرأ أولاً قبل أي skill آخر
---

# Taxi App — Master Architecture Reference

> **القانون الأول**: قبل أي widget جديد — ابحث في سجل الـ Widgets أدناه.  
> **القانون الثاني**: قبل أي ملف جديد — تحقق أنه غير موجود بالفعل.  
> **القانون الثالث**: قبل أي كود — اقرأ الملفات الحالية المرتبطة.  
> **القانون الرابع**: لا تنشئ service أو repository جديد قبل البحث في `core/services/` و `features/*/data/repositories/`.

---

## §1 هوية المشروع

| | |
|---|---|
| **Package** | `snapix` ← اسم الـ package في كل imports |
| **Framework** | Flutter 3.x / Dart SDK `>=3.3.0 <4.0.0` |
| **State** | `flutter_bloc: ^8.1.0` — Bloc للمعقد، Cubit للبسيط |
| **Navigation** | `go_router: ^14.2.7` ← `core/constants/app_routes.dart` فقط |
| **Maps** | `google_maps_flutter: ^2.9.0` + barrel `core/map/app_map.dart` |
| **Backend** | `supabase_flutter: ^2.5.0`: Auth OTP + Realtime + PostgreSQL |
| **Storage** | `R2StorageService` (R2/S3 — صور ووثائق السائق) |
| **FCM** | `firebase_messaging: ^15.1.3` + `FCMService` |
| **Crashlytics** | `firebase_crashlytics: ^4.1.0` عبر `AppLogger.initCrashlytics()` |
| **i18n** | ARB → `core/localization/l10n/` → auto-generated في `core/localization/generated/` |
| **Design Import** | `package:snapix/core/theme/design_system.dart` فقط |
| **Equatable** | `equatable: ^2.0.5` ← إلزامي في كل Events وStates |

---

## §2 هيكل المجلدات (مقدّس)

```
lib/
├── main.dart                          # entry point — لا تعدّل إلا نادراً
├── firebase_options.dart              # auto-generated — لا تعدّل أبداً
├── core/                              # بنية تحتية — بلا feature logic
│   ├── bloc/
│   │   └── location_permission_cubit.dart  # Cubit لإذن الموقع
│   ├── constants/
│   │   ├── app_routes.dart            # كل مسارات التنقل (AppRoutes)
│   │   ├── app_constants.dart         # ثوابت التطبيق + DefaultMapCenter
│   │   ├── env_constants.dart         # Supabase URL/Key — من --dart-define
│   │   └── map_styles.dart            # JSON styles للخريطة
│   ├── errors/
│   │   ├── exceptions.dart            # AppException + 7 subclasses
│   │   └── error_mapper.dart          # error keys → نصوص مترجمة
│   ├── localization/
│   │   ├── bloc/                      # LanguageBloc + Events + States
│   │   ├── generated/                 # auto-generated — لا تعدّل
│   │   └── l10n/
│   │       ├── app_ar.arb             # ← أضف مفاتيح جديدة هنا
│   │       └── app_en.arb             # ← أضف مفاتيح جديدة هنا
│   ├── map/                           # كل شيء خاص بالخريطة
│   │   ├── builders/app_map_hexagon_builder.dart
│   │   ├── constants/app_map_constants.dart
│   │   ├── controllers/app_map_controller.dart
│   │   ├── factories/app_map_marker_factory.dart
│   │   ├── utils/
│   │   │   ├── app_map_bearing.dart   # حساب اتجاه السيارة
│   │   │   ├── app_map_locating_overlay.dart
│   │   │   ├── map_marker_helpers.dart # createCircleMarker(Color)
│   │   │   └── map_point_helpers.dart  # tripPoint, samePoint
│   │   ├── widgets/
│   │   │   ├── app_google_map.dart
│   │   │   ├── app_map_my_location_button.dart
│   │   │   ├── map_circle_button.dart
│   │   │   └── trip_status_pill.dart
│   │   └── app_map.dart               # BARREL ← استورد هذا فقط
│   ├── models/                        # نماذج مشتركة عبر features
│   │   ├── app_config_model.dart
│   │   ├── bonus_progress_model.dart
│   │   ├── bonus_rule_model.dart
│   │   ├── complaint_message_model.dart
│   │   ├── complaint_model.dart
│   │   ├── conversation_model.dart
│   │   ├── driver_earnings_model.dart
│   │   ├── driver_info_model.dart
│   │   ├── driver_profile_model.dart   # نموذج السائق الأشمل (10 KB)
│   │   ├── message_model.dart
│   │   ├── notification_model.dart
│   │   ├── revision_request_model.dart
│   │   ├── trip_details_model.dart     # نموذج تفاصيل الرحلة (8 KB)
│   │   ├── trip_offer_model.dart
│   │   ├── trip_route_plan_model.dart
│   │   └── trip_route_waypoint_model.dart
│   ├── repositories/
│   │   ├── app_config_repository.dart  # إعدادات التطبيق من DB
│   │   └── driver_earnings_helper.dart
│   ├── router/app_router.dart          # تعريف كل routes (20 KB)
│   ├── services/                       # كل الخدمات هنا فقط
│   │   ├── cell_subscription_service.dart  # Geohash-based driver radar
│   │   ├── connectivity_service.dart
│   │   ├── directions_service.dart
│   │   ├── fcm_service.dart
│   │   ├── heatmap_service.dart
│   │   ├── location_permission_service.dart
│   │   ├── location_service.dart       # أشمل service موقع (12 KB)
│   │   ├── logout_coordinator.dart
│   │   ├── presence_service.dart
│   │   ├── r2_storage_service.dart     # رفع صور/ملفات للـ R2
│   │   ├── supabase_service.dart
│   │   ├── trip_broadcast_service.dart # بث تحديثات الرحلة للـ driver
│   │   └── user_presence_service.dart
│   ├── theme/
│   │   ├── bloc/                       # ThemeBloc — dark/light toggle
│   │   ├── app_colors.dart
│   │   ├── app_radius.dart
│   │   ├── app_shadows.dart
│   │   ├── app_spacing.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_theme.dart
│   │   ├── design_system.dart          # BARREL ← استورد هذا فقط
│   │   └── theme_extensions.dart       # context.bgColor, context.ts, إلخ
│   ├── utils/
│   │   ├── app_logger.dart             # نظام logging الوحيد
│   │   ├── app_toast.dart              # نظام toast الوحيد
│   │   ├── geohash_helper.dart         # GeohashHelper.encode/getNeighborCells
│   │   ├── map_camera_utils.dart       # حساب bounds للخريطة
│   │   ├── retry_helper.dart           # withRetry<T>(op, maxAttempts, delay)
│   │   ├── trip_status.dart            # TripStatus enum + transitions
│   │   └── uuid_helper.dart            # UuidHelper.generate()
│   └── widgets/
│       ├── widgets.dart                # BARREL ← استورد هذا فقط
│       └── [19 ملف widget فردي]
└── features/
    ├── auth/    data/ + domain/ + presentation/
    ├── driver/  data/ + presentation/
    ├── user/    data/ + domain/ + presentation/
    ├── trips/   data/ + domain/ + presentation/  ← ⭐ SHARED widgets
    ├── wallet/  data/ + presentation/
    ├── ride_offer/  (داخل driver home flow)
    └── shared/  data/ + presentation/
```

### قواعد المجلدات — NEVER تنتهك
- ❌ `lib/services/` → ✅ `lib/core/services/`
- ❌ Feature logic في `core/`
- ❌ Shared widget في `driver/` أو `user/` → ✅ `trips/presentation/widgets/`
- ❌ ملفات `.bak`, `.old`, `.zip` داخل المشروع
- ❌ Service جديد خارج `core/services/`
- ❌ Model مشترك داخل feature خاصة → ✅ `core/models/`

---

## §3 سجل الـ Widgets الكامل

### Core Widgets ← `import 'package:snapix/core/widgets/widgets.dart';`

| Widget | الغرض |
|---|---|
| `AppButton` | زر gradient قياسي + loading state |
| `AppTextField` | حقل إدخال موحّد + validation |
| `AppPhoneField` | حقل هاتف دولي (intl_phone_field wrapper) — `onChanged: (String e164)` |
| `AppCard` | كارت جاهز (radius 16 + shadow + border) |
| `AppAvatar` | صورة دائرية + fallback |
| `AppBadge` | شارة ملوّنة صغيرة |
| `AppTripStatusChip` | chip لحالة الرحلة مع لون تلقائي |
| `AppEmptyState` | حالة فارغة (icon + title + subtitle + action) |
| `AppErrorState` | حالة خطأ (icon + message + retry) |
| `AppLoadingState` | shimmer skeleton |
| `AppSectionHeader` | عنوان قسم + optional action |
| `AppInfoRow` | صف label + value للمعلومات |
| `AppConfirmSheet` | bottom sheet تأكيد (icon + title + buttons) |
| `AppCachedImage` | صورة شبكة + caching + placeholder |
| `AppShimmer` | تأثير shimmer مخصص |
| `AppDrawer` | درج تنقل جانبي (17.9 KB — لا تنسخه) |
| `BottomSheetContainer` | غلاف قياسي لكل bottom sheets |
| `MapButton` | زر دائري للخريطة |
| `StatCard` | كارت إحصائية (label + value + icon) |

> ⚠️ ملفات موجودة لكن **خارج الـ barrel** — استورد مباشرة:
> - `location_permission_cta.dart` → `import 'package:snapix/core/widgets/location_permission_cta.dart';`
> - `custom_animated_bottom_nav.dart` → `import 'package:snapix/core/widgets/custom_animated_bottom_nav.dart';`

### Trip Widgets ← `import 'package:snapix/features/trips/presentation/widgets/trip_widgets.dart';`

| Widget | الغرض |
|---|---|
| `SharedAnimatedTripCard` | كارت رحلة + fade/slide animation |
| `SharedTripListView` | قائمة رحلات + empty state |
| `SharedSegmentedControl` | 3 تبويبات: InProgress / Completed / Cancelled |
| `SharedTripsHeader` | header gradient بعدادات |
| `TripPriceBox` | fare + coupon + paid status |
| `TripStatsBox` | distance + duration + vehicle icon |
| `TripTimeline` | خط أفقي pickup→destination |
| `TripActionButton` | زر gradient + icon + label |
| `TripNightDialog` | modal لإدخال بيانات ليلية |
| `WaypointsTimeline` | waypoints عمودية بعناوين |

### Map Items ← `import 'package:snapix/core/map/app_map.dart';`

| Item | الغرض |
|---|---|
| `AppGoogleMap` | خريطة Google موحّدة dark/light |
| `MapCircleButton` | زر دائري 42px فوق الخريطة |
| `TripStatusPill` | pill ملوّنة لحالة الرحلة |
| `AppMapController` | wrapper لـ GoogleMapController |
| `AppMapMyLocationButton` | زر الموقع الحالي |
| `AppMapMarkerFactory` | مصنع الـ markers (createCircleMarker, createCarMarker) |
| `AppMapHexagonBuilder` | رسم hexagonal zones |
| `AppMapBearing` | حساب اتجاه السيارة على الخريطة |
| `tripPoint(double?, double?)` | LatLng من nullable doubles |
| `samePoint(LatLng?, LatLng?)` | مقارنة نقطتين بأمان |

### قاعدة Widget الحديدية
```
قبل إنشاء widget جديدة:
1. ابحث في الجداول أعلاه
2. إذا وجدت مشابهة → أضف parameters بدل إنشاء جديدة
3. مشتركة بين driver/user → trips/presentation/widgets/
4. خاصة بشاشة → private _Widget داخل ملف الشاشة نفسه
```

---

## §4 AppRoutes — كل المسارات الموجودة

```dart
import 'package:snapix/core/constants/app_routes.dart';

// Auth
AppRoutes.splash              // '/splash'
AppRoutes.onboarding          // '/onboarding'
AppRoutes.login               // '/login'
AppRoutes.register            // '/register'
AppRoutes.registerUser        // '/register/user'
AppRoutes.registerDriver      // '/register/driver'
AppRoutes.pendingVerification // '/pending-verification'
AppRoutes.privacyPolicy       // '/privacy-policy'
AppRoutes.helpSupport         // '/help-support'

// User
AppRoutes.userHome            // '/user/home'
AppRoutes.userProfile         // '/user/profile'
AppRoutes.userTrips           // '/user/trips'
AppRoutes.userMessages        // '/user/messages'
AppRoutes.userChatbot         // '/user/chatbot'
AppRoutes.userNotifications   // '/user/notifications'
AppRoutes.userLocationSelect  // '/user/location-select'
AppRoutes.userPricing         // '/user/pricing'
AppRoutes.userMeetingPoint    // '/user/meeting-point'
AppRoutes.userSearching       // '/user/searching'
AppRoutes.userTracking        // '/user/tracking'
AppRoutes.userRating          // '/user/rating'
AppRoutes.userTripDetails     // '/user/trip-details'
AppRoutes.userComplaints      // '/user/complaints'
AppRoutes.userWallet          // '/user/wallet'

// Driver
AppRoutes.driverHome          // '/driver/home'
AppRoutes.driverProfile       // '/driver/profile'
AppRoutes.driverTrips         // '/driver/trips'
AppRoutes.driverMessages      // '/driver/messages'
AppRoutes.driverChatbot       // '/driver/chatbot'
AppRoutes.driverNotifications // '/driver/notifications'
AppRoutes.driverTripDetails   // '/driver/trip-details'
AppRoutes.driverRating        // '/driver/rating'
AppRoutes.driverComplaints    // '/driver/complaints'
AppRoutes.driverWallet        // '/driver/wallet'
AppRoutes.driverBonus         // '/driver/bonus'
AppRoutes.driverRequestFeed   // '/driver/request-feed'
AppRoutes.driverRevision      // '/driver/revision'
AppRoutes.driverCorridorPicker// '/driver/corridor-picker'
```

---

## §5 Services الكاملة في `core/services/`

| Service | الغرض | طريقة الوصول |
|---|---|---|
| `CellSubscriptionService` | Geohash radar — يتتبع السائقين القريبين | `CellSubscriptionService.instance.subscribeToCells(lat, lng)` |
| `TripBroadcastService` | يبث تحديثات الرحلة النشطة للـ driver | Singleton |
| `LocationService` | GPS + permissions + stream موقع مستمر | Instance |
| `LocationPermissionService` | طلب/التحقق من إذن الموقع | Static methods |
| `FCMService` | Firebase push notifications + local display | `FCMService().initialize()` |
| `ConnectivityService` | مراقبة الاتصال بالإنترنت | `ConnectivityService().init()` |
| `DirectionsService` | Google Directions API — رسم المسارات | Instance |
| `HeatmapService` | بيانات خريطة الكثافة | Instance |
| `R2StorageService` | رفع صور/وثائق لـ R2 (Cloudflare/S3) | `R2StorageService()` |
| `UserPresenceService` | online/offline للمستخدم | Instance |
| `PresenceService` | presence عامة | Instance |
| `LogoutCoordinator` | تنسيق تسجيل الخروج عبر البلوكات | Singleton |

---

## §6 قواعد الكود الملزمة

### حجم الملفات
| نوع | الحد | عند الاقتراب |
|---|---|---|
| Screen | 500 سطر | 400 → ابدأ استخراج widgets |
| Widget | 200 سطر | 150 → فكر في التقسيم |
| BLoC | 300 سطر | 250 → helper methods |

> ⚠️ الملفات الحالية المخالفة (للمراجعة فقط — لا تضف إليها):
> - `tracking_screen.dart` ~1400 سطر
> - `trip_details_screen.dart` (driver) ~1800 سطر
> - `location_selection_screen.dart` ~2500 سطر
> - `complaints_screen.dart` ~700 سطر

### التسمية
```dart
// ملفات: snake_case.dart
// Classes/Widgets: PascalCase
class UserTripDetailsScreen extends StatefulWidget {}
// Private widgets: _PascalCase داخل الملف
class _DriverStrip extends StatelessWidget {}
// Events: فعل + اسم
class LoadDriverTrips extends TripsEvent {}
// States: اسم + حالة
class TripsLoaded extends TripsState {}
// Cubits بسيطة: XCubit + XState (ملف واحد أو اثنان)
// BLoCs معقدة: XBloc + XEvent + XState (3 ملفات)
```

### Import Order
```dart
// 1. Dart SDK
import 'dart:async';
// 2. Flutter
import 'package:flutter/material.dart';
// 3. Third-party
import 'package:flutter_bloc/flutter_bloc.dart';
// 4. Core (barrel أولاً)
import 'package:snapix/core/theme/design_system.dart';
import 'package:snapix/core/widgets/widgets.dart';
import 'package:snapix/core/map/app_map.dart';
// 5. Features
import 'package:snapix/features/trips/presentation/widgets/trip_widgets.dart';
// 6. Relative (نفس feature)
import '../bloc/trips_bloc.dart';

// ❌ استيراد مباشر بدل barrel
import 'package:snapix/features/trips/presentation/widgets/trip_price_box.dart';
// ❌ مسار قديم
import 'package:snapix/services/fcm_service.dart';
// ✅ صحيح
import 'package:snapix/core/services/fcm_service.dart';
```

---

## §7 نظام التصميم — import واحد

```dart
import 'package:snapix/core/theme/design_system.dart';
// يمنحك: AppColors, AppSpacing, AppRadius, AppTextStyles,
//         AppShadows, AppThemeX (context extensions), TextStyleX

// ── الألوان الثابتة ──
AppColors.primary      // #4C8BF5 أزرق العلامة
AppColors.secondary    // #1FC87A أخضر القبول
AppColors.success      // #1FC87A
AppColors.error        // #FF4060
AppColors.warning      // #F5A524
AppColors.info         // #3B82F6
AppColors.primaryGradient    // LinearGradient أزرق
AppColors.successGradient    // LinearGradient أخضر
AppColors.primarySurface20   // 20% primary جاهز

// ── الألوان الديناميكية (dark/light) — NEVER hardcode ──
context.bgColor          // خلفية الشاشة
context.cardColor        // سطح الكارت
context.elevatedColor    // inputs, chips
context.divColor         // فواصل وحدود
context.sheetColor       // bottom sheets
context.textPrimary      // نص رئيسي
context.textSecondary    // نص ثانوي
context.textDisabled     // نص معطّل

// ── المسافات ──
AppSpacing.xs=4  .sm=8  .md=12  .lg=16  .xl=20  .xxl=24  .xxxl=32  .huge=48
// SizedBox جاهز: AppSpacing.vLg  AppSpacing.hMd
// EdgeInsets: AppSpacing.card  AppSpacing.screen  AppSpacing.sheet

// ── الزوايا ──
AppRadius.xl_    // BorderRadius.circular(16) للكروت
AppRadius.xxl_   // BorderRadius.circular(20) للأزرار
AppRadius.full_  // BorderRadius.circular(100) للـ chips
AppRadius.sheetTop  // زوايا علوية للـ bottom sheets

// ── الطباعة ──
context.ts.headlineSm   // عنوان الشاشة
context.ts.titleMd      // عنوان الكارت
context.ts.bodyMd       // نص عادي
context.ts.labelSm      // نصوص الأزرار الصغيرة
context.ts.priceLg      // عرض الأسعار الكبيرة
context.ts.captionMd    // تاريخ، تفاصيل ثانوية
// مع لون: context.ts.titleMd.colored(context.textPrimary)

// ❌ NEVER:
color: Color(0xFF2196F3)         // ← hardcoded
color: Colors.blue               // ← hardcoded
color.withOpacity(0.3)           // ← deprecated
// ✅ ALWAYS:
color.withValues(alpha: 0.3)     // ← صحيح
AppColors.primarySurface20       // ← 20% جاهز
```

---

## §8 Navigation — AppRoutes فقط

```dart
// ✅ CORRECT
context.push(AppRoutes.driverTripDetails, extra: tripId);
context.push(AppRoutes.userWallet);
context.go(AppRoutes.userHome);
context.pop();

// ❌ WRONG
context.push('/driver/trip-details/$tripId');  // ← string hardcoded
Navigator.pushNamed(context, '/user/wallet');  // ← Navigator المباشر
```

---

## §9 BLoC Rules

```dart
// ✅ Template BLoC States
abstract class TripsState extends Equatable {
  @override List<Object?> get props => [];
}
class TripsLoading extends TripsState {}
class TripsEmpty   extends TripsState {}
class TripsLoaded  extends TripsState {
  final List<TripModel> trips;
  const TripsLoaded(this.trips);
  @override List<Object?> get props => [trips];
}
class TripsError extends TripsState {
  final String message;
  const TripsError(this.message);
  @override List<Object?> get props => [message];
}

// قواعد BLoC:
// ❌ NEVER business logic في widgets
// ❌ NEVER وصول مباشر لـ Repository من widget
// ❌ NEVER emit بعد close() — استخدم if (!isClosed)
// ✅ ALWAYS Equatable في events وstates
// ✅ ALWAYS buildWhen لمنع rebuilds غير ضرورية
// ✅ ALWAYS Models مكتوبة في States (لا Map<String, dynamic>)

// ❌ ANTI-PATTERN — موجود في المشروع في عدة ملفات:
class TrackingLoaded extends TrackingState {
  final Map<String, dynamic> trip;  // ❌ بلا type safety
}
// ✅ CORRECT:
class TrackingLoaded extends TrackingState {
  final TripDetailsModel trip;      // ✅ type-safe
  final DriverProfileModel? driver; // ✅ nullable model
}
```

---

## §10 TripStatus — القيم الحديدية

```dart
import 'package:snapix/core/utils/trip_status.dart';

// DB strings ← → Flutter enum:
// 'scheduled'      ↔ TripStatus.scheduled
// 'searching'      ↔ TripStatus.searching
// 'accepted'       ↔ TripStatus.accepted
// 'driver_arriving'↔ TripStatus.driverArriving  (underscore!)
// 'in_progress'    ↔ TripStatus.inProgress       (underscore!)
// 'completed'      ↔ TripStatus.completed
// 'cancelled'      ↔ TripStatus.cancelled        (ليس 'canceled'!)

TripStatus.fromString('in_progress')  // → TripStatus.inProgress
status.toDbString()                    // → 'in_progress'
status.isTerminal                      // completed أو cancelled
status.isActive
status.isCancellable
status.canTransitionTo(next)

// ❌ NEVER
if (status == 'in_progress') { }   // ← string hardcoded
if (status == 'in-progress') { }   // ← خطأ إملائي قاتل
```

---

## §11 Utilities الجاهزة — لا تعيد اختراعها

```dart
// ── Retry ──
import 'package:snapix/core/utils/retry_helper.dart';
final result = await withRetry(
  () => _repo.fetchSomething(),
  maxAttempts: 3,
  initialDelay: const Duration(milliseconds: 500),
  retryIf: (e) => e is NetworkException,
  onRetry: (e, attempt) => AppLogger.warning('Retry #$attempt', tag: 'Repo'),
);

// ── Geohash ──
import 'package:snapix/core/utils/geohash_helper.dart';
final cell = GeohashHelper.encode(lat, lng, precision: 6);
final neighbors = GeohashHelper.getNeighborCells(cell);

// ── UUID ──
import 'package:snapix/core/utils/uuid_helper.dart';
final id = UuidHelper.generate();

// ── Map Camera ──
import 'package:snapix/core/utils/map_camera_utils.dart';
final bounds = MapCameraUtils.boundsFromPoints([pickup, destination, ...waypoints]);

// ── Toast ──
AppToast.success('تم قبول الرحلة');
AppToast.error('فشل الاتصال');
AppToast.warning('تحذير');
AppToast.info('جاري التحميل...');
AppToast.dismiss();

// ── Logger ──
AppLogger.info('Trip accepted', tag: 'TripsBloc');
AppLogger.warning('Retry #$n', tag: 'Repo');
AppLogger.error('Failed: $tripId', tag: 'Repo', error: e, stackTrace: st);
AppLogger.debug('Dev only', tag: 'Dev');
final stop = AppLogger.startTimer('fetchTrips');
await fetch(); stop(); // ⚡ fetchTrips → 124ms
```

---

## §12 Localization — لا نص مُضمَّن

```dart
final l = AppLocalizations.of(context)!;
Text(l.tripCompleted)                              // ✅
Text('Trip completed')                             // ❌

// مفاتيح جديدة → app_ar.arb + app_en.arb معاً
// ثم شغّل: flutter gen-l10n
// لا تعدّل core/localization/generated/ يدوياً
```

---

## §13 StatefulWidget — أنماط إلزامية

```dart
// ✅ Pattern المثالي
class _SomeScreenState extends State<SomeScreen> {
  StreamSubscription? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<XBloc>().add(const LoadX());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _doAsync() async {
    final result = await someRepo.fetch();
    if (!mounted) return; // ✅ بعد كل await
    setState(() => _data = result);
  }
}
```

---

## §14 قائمة التحقق النهائية

```
□ flutter analyze → 0 errors, 0 warnings
□ لا imports غير مستخدمة
□ لا ألوان hardcoded — كلها من AppColors/context
□ لا نصوص hardcoded — كلها من AppLocalizations
□ لا print()/debugPrint() — كلها AppLogger
□ لا inline toast — كلها AppToast
□ لا ملفات > 500 سطر
□ لا widget مكرر — تحقق من سجل الـ Widgets (§3)
□ لا Map<String, dynamic> في States — استخدم Models
□ Widgets المشتركة عبر barrel files
□ Services في core/services/ فقط
□ withValues(alpha:x) بدل withOpacity(x)
□ AppRoutes للتنقل — لا strings hardcoded
□ dispose() يلغي كل Subscriptions و Timers
□ mounted check بعد كل await في StatefulWidget
□ WidgetsBinding.addPostFrameCallback عند initState مع context
□ Equatable في كل Events وStates
□ BlocBuilder لديه buildWhen مناسب
```

---

## §15 مرجع سريع للـ Skills

| الموضوع | الـ Skill |
|---|---|
| Performance, const, rebuilds | `flutter-performance` |
| Design System كامل، أنيميشن | `premium-ui-standards` |
| Supabase, Repository, RLS | `supabase-database` |
| AppException, try/catch | `error-handling` |
| تحقيق شامل في أي bug | `deep-investigation` |
| تزامن Flutter + Next.js | `cross-project-consistency` |
| StatefulWidget lifecycle | `§13 في هذا الملف` |
| Anti-patterns BLoC | `§9 في هذا الملف` |
| Forms, AppPhoneField, Validation | `flutter-forms-validation` |
| Services architecture | `§5 في هذا الملف` |
