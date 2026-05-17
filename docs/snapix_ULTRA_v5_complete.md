# Snapix Taxi — تقرير ULTRA v5 الشامل الكامل
## Flutter + Supabase PostgreSQL — التحليل العميق + نظام التصميم + تحسين الأداء الجذري

> **الإصدار:** v5.0 ULTRA | **التاريخ:** 2026-05-16
> **يتجاوز:** كل التقارير السابقة (v1 → v4 OMEGA)
> **المصادر:** 184 ملف Dart (قراءة سطر بسطر) + CSV Schema Introspection كامل + lib.zip (292 ملف)
> **المنهج:** تحليل كامل للكود الفعلي + 9 اكتشافات جديدة لم تُذكر في v4 + نظام تصميم كامل + خطة أداء شاملة
> **الهدف:** تطبيق بلا أخطاء، أداء عالي، سهل التطوير، نظام تصميم موحّد

---

## 📋 فهرس المحتويات

| القسم | العنوان |
|-------|---------|
| **PART A** | **ما زِدته فوق v4 — ملخص الإضافات الحصرية** |
| 0 | الملخص التنفيذي المحدَّث |
| 1 | الاكتشافات الجديدة v5 — 9 مشاكل لم تُذكر في أي تقرير |
| **PART B** | **نظام التصميم الموحّد الكامل (Design System)** |
| 2 | `AppColors` — النسخة الكاملة المُحسَّنة |
| 3 | `AppSpacing` — نظام المسافات |
| 4 | `AppRadius` — نظام الزوايا |
| 5 | `AppTextStyles` — نظام الطباعة |
| 6 | `AppShadows` — نظام الظلال |
| 7 | `AppTheme` — الثيم المُصحَّح والمُكمَّل |
| 8 | `AppThemeX` — الـ Extensions المحدَّثة |
| **PART C** | **مكتبة الـ Widgets الكاملة** |
| 9 | الـ Widgets الحالية + إصلاحاتها |
| 10 | الـ Widgets الجديدة المطلوبة (15 widget) |
| **PART D** | **إصلاحات الأمان والبرمجة** |
| 11 | جميع مشاكل الأمان [SEC] مع الكود الكامل |
| 12 | جميع الأخطاء الوظيفية [FL] مع الكود الكامل |
| 13 | مشاكل قاعدة البيانات [DB] مع الـ SQL الكامل |
| 14 | الاكتشافات الجديدة [NEW-v4 + NEW-v5] مع الكود |
| **PART E** | **خطة تحسين الأداء الشاملة** |
| 15 | أداء Flutter — BLoC + Streams + UI |
| 16 | أداء قاعدة البيانات — Indexing + Vacuum + Connections |
| 17 | أداء الشبكة — Caching + Adaptive Polling |
| 18 | معمارية النظام — Logout Coordinator + FCM Decoupling |
| **PART F** | **خطة التنفيذ** |
| 19 | مصفوفة المخاطر الكاملة الموحَّدة (v5) |
| 20 | خطة الإصلاح المرحلية الكاملة |
| 21 | Dead Code الكامل + ملفات يجب حذفها |
| 22 | الملاحظات المعمارية النهائية |

---

## PART A — ما زِدته فوق v4

### 📌 الإضافات الحصرية لـ v5 (غير موجودة في أي تقرير سابق)

| الفئة | الإضافة |
|-------|---------|
| **9 اكتشافات جديدة** | مشاكل لم تُذكر في v4: double imports، AppToast.error بلون خاطئ، ThemeBloc، lightTheme=darkTheme، إلخ |
| **نظام تصميم كامل** | `AppSpacing`, `AppRadius`, `AppTextStyles`, `AppShadows` — غير موجودة في الكود الحالي |
| **15 Widget جديد** | `AppTextField`, `AppCard`, `AppAvatar`, `AppBadge`, `AppEmptyState`, `AppErrorState`، إلخ |
| **تحسين أداء شامل** | Adaptive Polling، BLoC stream optimization، Image cache strategy، Heartbeat jitter |
| **معمارية LogoutCoordinator** | حل موحَّد لتنظيف كل الـ services عند logout بدل التشتت في AuthBloc |
| **FCMService Callback Pattern** | فصل كامل بين services/ وfeatures/ |
| **DB أعمق** | Index على trips.status، autovacuum tuning، connection pooling، pg_stat_statements |
| **إصلاح AppToast** | error() يستخدم primary color بدل error color (خطأ مرئي) |
| **إصلاح Double Imports** | 4 ملفات بها import مكرر للـ AppColors |
| **كود SQL كامل** | كل إصلاح DB بالـ SQL الكامل الجاهز للتنفيذ |

---

## 0. الملخص التنفيذي المحدَّث

```
المشروع: Snapix Taxi — تطبيق توكسي Flutter + Supabase
الحالة:  Pre-production — 92 رحلة، 7 مستخدمين، 3 سائقين فعليين
الحجم:   32 جدول DB | 87 function | 184 ملف Dart | 45,000+ سطر كود
الهدف:   رفع جودة الكود من "جيد مع مشاكل" إلى "production-ready"
```

### الحالة العامة (محدَّثة)

| الجانب | التقييم الحالي | الهدف بعد v5 |
|--------|---------------|--------------|
| أمان DB | 🔴 4 ثغرات حرجة | ✅ صفر ثغرات |
| كود Flutter | ⚠️ 15+ خطأ | ✅ مستقر بالكامل |
| نظام التصميم | ⚠️ جزئي (ألوان فقط) | ✅ كامل (5 ملفات) |
| مكتبة الـ Widgets | ⚠️ 8 widgets أساسية | ✅ 23 widget |
| أداء DB | ⚠️ Bloat + بدون ANALYZE | ✅ محسَّن بالكامل |
| معمارية FCM | ⚠️ انعكاس معماري | ✅ Callback pattern |
| Logout Cleanup | ⚠️ متشتت في AuthBloc | ✅ LogoutCoordinator |
| Dead Code | ⚠️ 4+ ملفات | ✅ محذوف |

---

## 1. الاكتشافات الجديدة v5 — 9 مشاكل لم تُذكر في أي تقرير

---

### [V5-01] 🔴 HIGH — `AppTheme.lightTheme` يُعيد `darkTheme` — لا Light Theme حقيقي

**الملف:** `lib/core/theme/app_theme.dart`

**الكود الحالي:**
```dart
class AppTheme {
  static ThemeData get lightTheme => darkTheme; // ← دائماً يُعيد الـ dark!
  static ThemeData get darkTheme => ThemeData(brightness: Brightness.dark, ...);
}
```

**الأثر:** حتى لو المستخدم فعّل Light Mode من `ThemeBloc`، التطبيق يبقى Dark. `ThemeMode.light` لا يعمل.

**الإصلاح الكامل:**
```dart
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F7FF),
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: Color(0xFF1A1F36),
      error: AppColors.error,
    ),
    useMaterial3: true,
    fontFamily: GoogleFonts.cairo().fontFamily,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1A1F36),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        side: BorderSide(color: Color(0xFFE8EAF6), width: .8),
      ),
    ),
    // ... باقي المكونات
  );

  static ThemeData get darkTheme => ThemeData(/* الحالي */);
}
```

> **ملاحظة:** إذا قررت بقاء التطبيق Dark-only، احذف `ThemeBloc` و`ToggleTheme` event وبسّط الكود.

---

### [V5-02] 🔴 HIGH — `AppToast.error()` يستخدم `AppColors.primary` (أزرق) كخلفية بدل `AppColors.error` (أحمر)

**الملف:** `lib/core/utils/app_toast.dart`

**الكود الحالي:**
```dart
static void error(String message) => Fluttertoast.showToast(
  msg: message,
  backgroundColor: AppColors.primary,   // ← أزرق! للخطأ!
  textColor: AppColors.textPrimary,
  ...
);
```

**الأثر:** رسائل الخطأ (فشل تسجيل دخول، خطأ شبكة) تظهر بخلفية زرقاء — مُربِكة للمستخدم ومعارضة لنظام الألوان الدلالي.

**الإصلاح:**
```dart
static void error(String message) => Fluttertoast.showToast(
  msg: message,
  backgroundColor: AppColors.error,     // ← أحمر صح
  textColor: AppColors.white,
  gravity: ToastGravity.TOP,            // الأخطاء أفضل في الأعلى
  toastLength: Toast.LENGTH_LONG,
  fontSize: 14,
);

static void success(String message) => Fluttertoast.showToast(
  msg: message,
  backgroundColor: AppColors.success,
  textColor: AppColors.white,           // أبيض على أخضر أوضح
  gravity: ToastGravity.BOTTOM,
  toastLength: Toast.LENGTH_SHORT,
  fontSize: 14,
);
```

---

### [V5-03] 🟠 HIGH — Double Import في 4 ملفات (تعارض بين Relative و Package Import)

**الملفات المتأثرة:**

| الملف | السطر | المشكلة |
|-------|-------|---------|
| `app_theme.dart` | 4+5 | `import 'app_colors.dart'` + `import 'package:snapix/core/theme/app_colors.dart'` |
| `app_button.dart` | 3+5 | `import '../theme/app_colors.dart'` + `import 'package:snapix/core/theme/app_colors.dart'` |
| `bottom_sheet_container.dart` | 3+4 | مشابه |
| `map_button.dart` | 3+4 | مشابه |

**الأثر:** يسبب `Duplicate import` warning + يزيد وقت compile. في بعض إصدارات Dart قد يسبب تعارضاً في type checking.

**الإصلاح:** احذف الـ relative import واحتفظ بالـ package import فقط في كل ملف:
```dart
// ✅ استخدم هذا فقط (package import — consistent في كل المشروع)
import 'package:snapix/core/theme/app_colors.dart';

// ❌ احذف هذا
import 'app_colors.dart'; // أو '../theme/app_colors.dart'
```

---

### [V5-04] 🟠 MEDIUM — `ThemeBloc` يبدأ بـ `ThemeDark()` Hardcoded قبل قراءة الـ Prefs

**الملف:** `lib/core/theme/bloc/theme_bloc.dart`

**الكود الحالي:**
```dart
ThemeBloc(this._prefs) : super(ThemeDark()) { // ← دائماً يبدأ Dark
  on<LoadSavedTheme>(_onLoad);               // ثم يقرأ الـ prefs (async)
  ...
}
```

**الأثر:** عند أول build، حتى لو المستخدم اختار Light Mode، التطبيق يومض بـ Dark ثم يتحول — مُلاحَظ بصرياً (Flash of Wrong Theme).

**الإصلاح:**
```dart
// الأفضل: اقرأ الـ prefs قبل runApp
// في main():
final isDark = prefs.getBool('app_theme_dark') ?? true;
final initialTheme = isDark ? ThemeDark() : ThemeLight();

BlocProvider<ThemeBloc>(
  create: (_) => ThemeBloc(prefs, initialState: initialTheme),
)

// في ThemeBloc:
ThemeBloc(this._prefs, {ThemeState? initialState})
    : super(initialState ?? ThemeDark()) { ... }
```

---

### [V5-05] 🟠 MEDIUM — `main.dart` يحتوي 10 أسطر فارغة متتالية (Dead Code/Debug Remnants)

**الملف:** `lib/main.dart`

**الكود:**
```dart
import 'core/repositories/app_config_repository.dart';

// ← 10 أسطر فارغة هنا (سطر 26-35)
// هذا يدل على كود محذوف غير منظَّف (imports أو تعليمات debug)

void main() async {
```

**الإصلاح:** احذف الأسطر الفارغة + نظّم الـ imports بترتيب (dart: → package: → relative:).

---

### [V5-06] 🟠 MEDIUM — `ConnectivityService.init()` يُستدعى بدون `await` في `main()`

**الملف:** `lib/main.dart`

**الكود الحالي:**
```dart
ConnectivityService().init(); // ← fire-and-forget بدون await
```

**الأثر:** إذا `init()` تُنشئ subscriptions، قد تُنشأ مكررة إذا استُدعيت مرتين. بالإضافة لذلك، أي خطأ في الـ init يُبتلع صامتاً.

**الإصلاح:**
```dart
await ConnectivityService().init(); // أو
ConnectivityService().init().catchError((e) {
  debugPrint('⚠️ ConnectivityService init failed: $e');
});
```

---

### [V5-07] 🟡 MEDIUM — `AppButton` لا يدعم `haptic feedback` — تجربة مستخدم ناقصة

**الملف:** `lib/core/widgets/app_button.dart`

**الكود الحالي:**
```dart
InkWell(
  onTap: inactive ? null : onPressed, // ← بدون haptic
  ...
)
```

**الإصلاح:**
```dart
InkWell(
  onTap: inactive ? null : () {
    HapticFeedback.lightImpact(); // ← أضف هذا
    onPressed?.call();
  },
  ...
)
```

---

### [V5-08] 🟡 LOW — `AppCachedImage` — `borderRadius` مُشفَّر كـ `8` ثابت (magic number)

**الملف:** `lib/core/widgets/app_cached_image.dart`

**الكود الحالي:**
```dart
decoration: BoxDecoration(
  color: context.cardColor,
  borderRadius: BorderRadius.circular(8), // ← magic number
),
```

**الإصلاح:**
```dart
borderRadius: BorderRadius.circular(AppRadius.sm), // ← من نظام التصميم
```

---

### [V5-09] 🟡 LOW — `AppConstants.defaultMapCenter` ثابت على الرياض — يجب أن يكون قابلاً للتكوين

**الملف:** `lib/core/constants/app_constants.dart`

**الكود الحالي:**
```dart
static const LatLng defaultMapCenter = LatLng(24.7136, 46.6753); // Riyadh — hardcoded
```

**الأثر:** إذا انتقل التطبيق لمدينة أخرى (القاهرة، دبي، إلخ)، يلزم تغيير الكود. `AppConfigRepository` موجود لكنه لا يُعيد `defaultMapCenter`.

**الإصلاح:**
```dart
// في app_config_repository.dart — أضف:
Future<LatLng?> getDefaultMapCenter() async {
  final config = await getAll();
  final lat = double.tryParse(config['default_lat'] ?? '');
  final lng = double.tryParse(config['default_lng'] ?? '');
  if (lat != null && lng != null) return LatLng(lat, lng);
  return null; // fallback للثابت
}

// في DB: أضف في app_config:
-- INSERT INTO app_config (key, value) VALUES ('default_lat', '24.7136');
-- INSERT INTO app_config (key, value) VALUES ('default_lng', '46.6753');
```

---

## PART B — نظام التصميم الموحَّد الكامل

### لماذا تحتاج نظام تصميم كامل؟

الكود الحالي عنده `AppColors` فقط. هذا يعني:
- المسافات (`padding`, `margin`) مُشفَّرة مباشرة في كل widget (12, 16, 20, 24 — scattered)
- الزوايا (`BorderRadius`) مُشفَّرة في كل مكان (12, 14, 16, 32 — غير متسقة)
- الـ Typography غير موحَّدة (fontSize 11, 12, 14, 16, 17 — بدون نظام)
- الظلال مكررة في كل widget (نفس `BoxShadow` مكتوب 5+ مرات)

---

## 2. `AppColors` — النسخة الكاملة المُحسَّنة

**الملف:** `lib/core/theme/app_colors.dart`

```dart
import 'package:flutter/material.dart';

/// نظام الألوان الموحَّد لتطبيق Snapix
/// كل لون له اسم دلالي واضح + تعليق
/// لا تستخدم Color() مباشرةً في أي مكان آخر — استخدم هذا الملف فقط
class AppColors {
  AppColors._(); // منع الإنشاء المباشر

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ألوان أساسية
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const white       = Colors.white;
  static const black       = Colors.black;
  static const transparent = Colors.transparent;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // خلفيات (Dark Mode)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const darkBg          = Color(0xFF070C18); // الخلفية الرئيسية
  static const darkSurface     = Color(0xFF181C2A); // بطاقات / cards
  static const darkElevated    = Color(0xFF1E2336); // عناصر مرفوعة / inputs
  static const darkDivider     = Color(0xFF252A3D); // فواصل / borders
  static const darkSheet       = Color(0xFF12151F); // primary tint / bottom sheets

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // خلفيات (Light Mode) — جديد في v5
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const lightBg         = Color(0xFFF5F7FF);
  static const lightSurface    = Color(0xFFFFFFFF);
  static const lightElevated   = Color(0xFFF0F2FF);
  static const lightDivider    = Color(0xFFE8EAF6);
  static const lightSheet      = Color(0xFFEEF1FF);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ألوان العلامة التجارية (Brand)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const primary         = Color(0xFF4C8BF5); // الأزرق الرئيسي
  static const primaryDark     = Color(0xFF3868C0); // أزرق داكن (gradient end)
  static const primaryLight    = Color(0xFF7AAEFF); // أزرق فاتح (hover states)
  static const primarySurface  = Color(0xFF12151F); // خلفية تحت primary icons

  static const secondary       = Color(0xFF1FC87A); // الأخضر (success + secondary action)
  static const secondaryDark   = Color(0xFF178A56); // أخضر داكن

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // لهجات (Accents)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const purple          = Color(0xFF9333EA);
  static const purpleDark      = Color(0xFF7E22CE);
  static const purpleLight     = Color(0xFFD8B4FE);
  static const indigo          = Color(0xFF4F46E5);
  static const indigoLight     = Color(0xFFA5B4FC);
  static const info            = Color(0xFF3B82F6);
  static const infoLight       = Color(0xFF93C5FD);
  static const amber           = Color(0xFFF59E0B); // جديد
  static const amberLight      = Color(0xFFFCD34D);
  static const teal            = Color(0xFF14B8A6); // جديد
  static const tealLight       = Color(0xFF5EEAD4);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // نصوص
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const darkTextPrimary   = Color(0xFFEEF0FF); // نص رئيسي (Dark)
  static const darkTextSecondary = Color(0xFF7B82A3); // نص ثانوي (Dark)
  static const darkTextDisabled  = Color(0xFF3A4060); // نص معطل (Dark)

  static const lightTextPrimary   = Color(0xFF1A1F36); // نص رئيسي (Light)
  static const lightTextSecondary = Color(0xFF636788); // نص ثانوي (Light)
  static const lightTextDisabled  = Color(0xFFAEB4D0); // نص معطل (Light)

  // Aliases للتوافق مع الكود القديم
  static const textPrimary   = darkTextPrimary;
  static const textSecondary = darkTextSecondary;
  static const textDisabled  = darkTextDisabled;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // دلالية (Semantic)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const success         = Color(0xFF1FC87A);
  static const successLight    = Color(0xFF6EE7B7);
  static const successSurface  = Color(0xFF0D2918); // خلفية success chips
  static const warning         = Color(0xFFF5A524);
  static const warningLight    = Color(0xFFFCD34D);
  static const warningSurface  = Color(0xFF2A1E08);
  static const error           = Color(0xFFFF4060);
  static const errorLight      = Color(0xFFFDA4AF);
  static const errorSurface    = Color(0xFF2A0A10);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // حالات الرحلة (Trip Status Colors)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const tripSearching   = Color(0xFF4C8BF5); // primary — بحث
  static const tripAccepted    = Color(0xFF9333EA); // purple — قُبلت
  static const tripInProgress  = Color(0xFF1FC87A); // success — جارية
  static const tripCompleted   = Color(0xFF7B82A3); // secondary — اكتملت
  static const tripCancelled   = Color(0xFFFF4060); // error — مُلغاة

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Aliases للتوافق (لا تحذفها — الكود القديم يستخدمها)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const background      = darkBg;
  static const surface         = darkSurface;
  static const surfaceElevated = darkElevated;
  static const divider         = darkDivider;
  static const primarySurface_ = darkSheet; // alias
  static const grey            = Colors.grey;
}
```

---

## 3. `AppSpacing` — نظام المسافات (جديد كلياً)

**الملف:** `lib/core/theme/app_spacing.dart` ← ملف جديد

```dart
/// نظام المسافات الموحَّد
/// استخدم هذه الثوابت بدل الأرقام المباشرة في padding / margin / gap
class AppSpacing {
  AppSpacing._();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // الوحدات الأساسية
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const double xs   = 4.0;   // مسافة صغيرة جداً (icon gaps، text gaps)
  static const double sm   = 8.0;   // مسافة صغيرة (داخل chips، badges)
  static const double md   = 12.0;  // مسافة متوسطة (بين عناصر)
  static const double lg   = 16.0;  // مسافة كبيرة (padding داخل cards)
  static const double xl   = 20.0;  // padding أساسي للشاشات
  static const double xxl  = 24.0;  // مسافات بين sections
  static const double xxxl = 32.0;  // مسافات كبيرة (bottom sheets)
  static const double huge = 48.0;  // مسافات ضخمة (hero sections)

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Padding جاهزة للاستخدام
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// Padding أفقي للشاشات
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: xl);

  /// Padding كامل للشاشات
  static const EdgeInsets screen = EdgeInsets.fromLTRB(xl, lg, xl, xxxl);

  /// Padding داخل Cards
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Padding داخل Cards كبيرة
  static const EdgeInsets cardLg = EdgeInsets.all(xl);

  /// Padding Bottom Sheets
  static const EdgeInsets sheet = EdgeInsets.fromLTRB(xl, lg, xl, 34);

  /// Padding Chips و Badges
  static const EdgeInsets chip = EdgeInsets.symmetric(horizontal: md, vertical: xs);

  /// Padding Buttons صغيرة
  static const EdgeInsets btnSm = EdgeInsets.symmetric(horizontal: lg, vertical: sm);
}
```

---

## 4. `AppRadius` — نظام الزوايا (جديد كلياً)

**الملف:** `lib/core/theme/app_radius.dart` ← ملف جديد

```dart
/// نظام الزوايا الموحَّد
/// بدل استخدام BorderRadius.circular(12) أو (14) أو (16) في كل مكان
class AppRadius {
  AppRadius._();

  static const double xs  = 6.0;   // badges صغيرة
  static const double sm  = 8.0;   // صور، أيقونات
  static const double md  = 12.0;  // inputs، chips
  static const double lg  = 14.0;  // buttons
  static const double xl  = 16.0;  // cards
  static const double xxl = 20.0;  // modals صغيرة
  static const double xxxl = 24.0; // bottom sheets
  static const double huge = 32.0; // drawers، main containers
  static const double full = 100.0; // دائري تام (avatars، toggles)

  // BorderRadius جاهزة
  static final xs_  = BorderRadius.circular(xs);
  static final sm_  = BorderRadius.circular(sm);
  static final md_  = BorderRadius.circular(md);
  static final lg_  = BorderRadius.circular(lg);
  static final xl_  = BorderRadius.circular(xl);
  static final xxl_ = BorderRadius.circular(xxl);
  static final xxxl_= BorderRadius.circular(xxxl);
  static final huge_= BorderRadius.circular(huge);
  static final full_= BorderRadius.circular(full);

  // Bottom Sheet (مُقطوع من الأعلى فقط)
  static final sheetTop = const BorderRadius.vertical(top: Radius.circular(xxxl));
  static final sheetTopXl = const BorderRadius.vertical(top: Radius.circular(huge));
}
```

---

## 5. `AppTextStyles` — نظام الطباعة (جديد كلياً)

**الملف:** `lib/core/theme/app_text_styles.dart` ← ملف جديد

```dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// نظام الطباعة الموحَّد لـ Snapix
/// بناءً على Cairo font مع نظام Type Scale واضح
class AppTextStyles {
  AppTextStyles._();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Display (أكبر العناوين)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const displayLg = TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5);
  static const displayMd = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.4);
  static const displaySm = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.3);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Headline (عناوين الشاشات)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const headlineLg = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static const headlineMd = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3);
  static const headlineSm = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Title (عناوين البطاقات)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const titleLg = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4);
  static const titleMd = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);
  static const titleSm = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Body (نصوص المحتوى)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const bodyLg = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6);
  static const bodyMd = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);
  static const bodySm = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.6);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Label (أزرار، chips، badges)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const labelLg = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2);
  static const labelMd = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2);
  static const labelSm = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2);
  static const labelXs = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Caption (نصوص صغيرة)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const captionMd = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: 0.2);
  static const captionSm = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, height: 1.4, letterSpacing: 0.1);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Mono (أرقام، كودات، أسعار)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const priceLg = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5, fontFeatures: [FontFeature.tabularFigures()]);
  static const priceMd = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.3, fontFeatures: [FontFeature.tabularFigures()]);
  static const priceSm = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.1, fontFeatures: [FontFeature.tabularFigures()]);
}
```

---

## 6. `AppShadows` — نظام الظلال (جديد كلياً)

**الملف:** `lib/core/theme/app_shadows.dart` ← ملف جديد

```dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// نظام الظلال الموحَّد
/// بدل تكرار BoxShadow في كل widget
class AppShadows {
  AppShadows._();

  // ظل خفيف (Cards، Inputs)
  static final soft = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
  ];

  // ظل متوسط (Map buttons، Floating elements)
  static final medium = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1)),
  ];

  // ظل قوي (Bottom Sheets، Modals)
  static final strong = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.24), blurRadius: 32, spreadRadius: 0, offset: const Offset(0, -6)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 8, spreadRadius: 0, offset: const Offset(0, -2)),
  ];

  // ظل الـ Primary Button
  static final primaryBtn = [
    BoxShadow(color: AppColors.primary.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 6)),
  ];

  // ظل الـ Success
  static final success = [
    BoxShadow(color: AppColors.success.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 5)),
  ];

  // ظل Drawer
  static final drawer = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.40), blurRadius: 48, offset: const Offset(8, 0)),
  ];
}
```

---

## 7. `AppTheme` — الثيم المُصحَّح والمكتمل

**الملف:** `lib/core/theme/app_theme.dart` (يحل محل الحالي بالكامل)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/app_spacing.dart';

class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color primary, Color secondary) =>
      GoogleFonts.cairoTextTheme(TextTheme(
        bodyLarge:   TextStyle(color: primary),
        bodyMedium:  TextStyle(color: primary),
        bodySmall:   TextStyle(color: secondary),
        labelLarge:  TextStyle(color: primary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: primary, fontWeight: FontWeight.w600),
        titleLarge:  TextStyle(color: primary, fontWeight: FontWeight.w700),
      ));

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Dark Theme (الرئيسي)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.darkSurface,
      onPrimary: AppColors.white,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.error,
      secondary: AppColors.secondary,
    ),
    useMaterial3: true,
    textTheme: _textTheme(AppColors.darkTextPrimary, AppColors.darkTextSecondary),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBg,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
      titleTextStyle: TextStyle(color: AppColors.darkTextPrimary, fontSize: 17, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        side: const BorderSide(color: AppColors.darkDivider, width: .8),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.darkDivider, thickness: .8),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.darkDivider, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.darkDivider, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.error, width: 1.8)),
      hintStyle: const TextStyle(color: AppColors.darkTextDisabled),
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
      prefixIconColor: AppColors.darkTextSecondary,
      suffixIconColor: AppColors.darkTextSecondary,
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
    ),
  );

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Light Theme (مُصحَّح — لم يكن موجوداً!)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      surface: AppColors.lightSurface,
      onPrimary: AppColors.white,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.error,
      secondary: AppColors.secondary,
    ),
    useMaterial3: true,
    textTheme: _textTheme(AppColors.lightTextPrimary, AppColors.lightTextSecondary),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        side: const BorderSide(color: AppColors.lightDivider, width: .8),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.lightDivider, thickness: .8),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.lightDivider, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.lightDivider, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
    ),
  );
}
```

---

## 8. `AppThemeX` — الـ Extensions المحدَّثة

**الملف:** `lib/core/theme/theme_extensions.dart` (يحل محل الحالي)

```dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ألوان الخلفية (تتكيف مع الـ Theme)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  Color get bgColor       => isDark ? AppColors.darkBg       : AppColors.lightBg;
  Color get cardColor     => isDark ? AppColors.darkSurface   : AppColors.lightSurface;
  Color get elevatedColor => isDark ? AppColors.darkElevated  : AppColors.lightElevated;
  Color get divColor      => isDark ? AppColors.darkDivider   : AppColors.lightDivider;
  Color get sheetColor    => isDark ? AppColors.darkSheet     : AppColors.lightSheet;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ألوان النص (تتكيف)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  Color get textPrimary   => isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textDisabled  => isDark ? AppColors.darkTextDisabled  : AppColors.lightTextDisabled;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Aliases للتوافق مع الكود القديم (لا تحذفها)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  Color get primaryTint   => sheetColor;
  Color get surfaceColor  => bgColor;
  Color get hBg           => bgColor;
  Color get hSurface      => cardColor;
  Color get hSurfaceEl    => elevatedColor;
  Color get hDivider      => divColor;
  Color get hTextPrimary  => textPrimary;
  Color get hTextSecondary => textSecondary;
  Color get hPrimaryBg    => primaryTint;
}
```

---

## PART C — مكتبة الـ Widgets الكاملة

## 9. الـ Widgets الحالية + إصلاحاتها

### `AppButton` — مُحسَّن (إضافة haptic + icon support + size variants)

```dart
// lib/core/widgets/app_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/app_shadows.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

enum AppButtonVariant { primary, secondary, outlined, ghost, danger }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.lg,
    this.leadingIcon,
    this.trailingIcon,
  });

  double get _height => switch (size) {
    AppButtonSize.sm => 40,
    AppButtonSize.md => 48,
    AppButtonSize.lg => 54,
  };

  double get _fontSize => switch (size) {
    AppButtonSize.sm => 13,
    AppButtonSize.md => 15,
    AppButtonSize.lg => 16,
  };

  @override
  Widget build(BuildContext context) {
    final bool inactive = isLoading || isDisabled;

    final (bg, fg, gradient, shadows) = switch (variant) {
      AppButtonVariant.primary   => (AppColors.primary, AppColors.white,
          inactive ? null : const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.centerLeft, end: Alignment.centerRight),
          inactive ? <BoxShadow>[] : AppShadows.primaryBtn),
      AppButtonVariant.secondary => (AppColors.secondary, AppColors.white, null, inactive ? <BoxShadow>[] : AppShadows.success),
      AppButtonVariant.danger    => (AppColors.error, AppColors.white, null, <BoxShadow>[]),
      AppButtonVariant.outlined  => (Colors.transparent, AppColors.primary, null, <BoxShadow>[]),
      AppButtonVariant.ghost     => (Colors.transparent, context.textPrimary, null, <BoxShadow>[]),
    };

    return Container(
      width: double.infinity,
      height: _height,
      decoration: BoxDecoration(
        gradient: inactive ? null : gradient,
        color: inactive ? context.elevatedColor : (gradient == null ? bg : null),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: variant == AppButtonVariant.outlined
            ? Border.all(color: inactive ? context.divColor : AppColors.primary, width: 1.5)
            : null,
        boxShadow: inactive ? null : shadows,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: inactive ? null : () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(AppColors.white)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leadingIcon != null) ...[
                        Icon(leadingIcon, size: _fontSize + 2,
                            color: inactive ? context.textDisabled : fg),
                        const SizedBox(width: 6),
                      ],
                      Text(text, style: TextStyle(fontSize: _fontSize,
                          fontWeight: FontWeight.w700,
                          color: inactive ? context.textDisabled : fg)),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 6),
                        Icon(trailingIcon, size: _fontSize + 2,
                            color: inactive ? context.textDisabled : fg),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
```

### `AppToast` — مُصحَّح (إصلاح V5-02)

```dart
// lib/core/utils/app_toast.dart
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

class AppToast {
  static void error(String message) => Fluttertoast.showToast(
    msg: message,
    backgroundColor: AppColors.error,   // ← مُصحَّح (كان primary خطأً)
    textColor: AppColors.white,
    gravity: ToastGravity.TOP,
    toastLength: Toast.LENGTH_LONG,
    fontSize: 14,
  );

  static void success(String message) => Fluttertoast.showToast(
    msg: message,
    backgroundColor: AppColors.success,
    textColor: AppColors.white,         // ← مُصحَّح (كان textPrimary)
    gravity: ToastGravity.BOTTOM,
    toastLength: Toast.LENGTH_SHORT,
    fontSize: 14,
  );

  static void warning(String message) => Fluttertoast.showToast(
    msg: message,
    backgroundColor: AppColors.warning,
    textColor: AppColors.black,
    gravity: ToastGravity.BOTTOM,
    toastLength: Toast.LENGTH_LONG,
    fontSize: 14,
  );

  static void info(String message) => Fluttertoast.showToast(
    msg: message,
    backgroundColor: AppColors.darkElevated,
    textColor: AppColors.darkTextSecondary,
    gravity: ToastGravity.BOTTOM,
    toastLength: Toast.LENGTH_SHORT,
    fontSize: 14,
  );

  static void dismiss() => Fluttertoast.cancel();
}
```

---

## 10. الـ Widgets الجديدة المطلوبة (15 Widget)

### `AppTextField` — Input موحَّد

```dart
// lib/core/widgets/app_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final IconData? prefixIcon;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.prefixIcon,
    this.suffix,
    this.inputFormatters,
    this.maxLines = 1,
    this.onTap,
    this.onChanged,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: TextStyle(color: context.textSecondary,
              fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          onTap: onTap,
          onChanged: onChanged,
          focusNode: focusNode,
          textInputAction: textInputAction,
          style: TextStyle(color: context.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20, color: context.textSecondary)
                : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
```

### `AppCard` — بطاقة موحَّدة

```dart
// lib/core/widgets/app_card.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/app_shadows.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool hasBorder;
  final bool hasShadow;
  final Color? backgroundColor;
  final double? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.hasBorder = true,
    this.hasShadow = false,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? AppRadius.xl;
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? context.cardColor,
        borderRadius: BorderRadius.circular(r),
        border: hasBorder ? Border.all(color: context.divColor, width: .8) : null,
        boxShadow: hasShadow ? AppShadows.soft : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(r),
          child: Padding(
            padding: padding ?? AppSpacing.card,
            child: child,
          ),
        ),
      ),
    );
  }
}
```

### `AppAvatar` — صورة المستخدم

```dart
// lib/core/widgets/app_avatar.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/widgets/app_cached_image.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;  // يُستخدم لعرض الحرف الأول إذا لا صورة
  final double size;
  final Color? backgroundColor;
  final bool showOnlineIndicator;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 48,
    this.backgroundColor,
    this.showOnlineIndicator = false,
  });

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? context.elevatedColor,
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? AppCachedImage(imageUrl: imageUrl!, width: size, height: size)
              : Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
        if (showOnlineIndicator)
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: context.bgColor, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
```

### `AppBadge` — شارة/علامة

```dart
// lib/core/widgets/app_badge.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/app_spacing.dart';

enum AppBadgeVariant { primary, success, warning, error, info, neutral }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final bool dot;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.dot = false,
  });

  (Color, Color) get _colors => switch (variant) {
    AppBadgeVariant.primary => (AppColors.primarySurface, AppColors.primary),
    AppBadgeVariant.success => (AppColors.successSurface, AppColors.success),
    AppBadgeVariant.warning => (AppColors.warningSurface, AppColors.warning),
    AppBadgeVariant.error   => (AppColors.errorSurface, AppColors.error),
    AppBadgeVariant.info    => (AppColors.primarySurface, AppColors.info),
    AppBadgeVariant.neutral => (AppColors.darkElevated, AppColors.darkTextSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: AppSpacing.chip,
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.xs_),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

### `AppTripStatusChip` — حالة الرحلة موحَّدة

```dart
// lib/core/widgets/app_trip_status_chip.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/utils/trip_status.dart';
import 'package:snapix/core/widgets/app_badge.dart';

class AppTripStatusChip extends StatelessWidget {
  final TripStatus status;
  final String Function(TripStatus) labelBuilder;

  const AppTripStatusChip({
    super.key,
    required this.status,
    required this.labelBuilder,
  });

  AppBadgeVariant get _variant => switch (status) {
    TripStatus.searching  => AppBadgeVariant.primary,
    TripStatus.accepted   => AppBadgeVariant.info,
    TripStatus.inProgress => AppBadgeVariant.success,
    TripStatus.completed  => AppBadgeVariant.neutral,
    TripStatus.cancelled  => AppBadgeVariant.error,
  };

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: labelBuilder(status),
      variant: _variant,
      dot: status == TripStatus.inProgress || status == TripStatus.searching,
    );
  }
}
```

### `AppEmptyState` — حالة فارغة موحَّدة

```dart
// lib/core/widgets/app_empty_state.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: context.elevatedColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: context.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: TextStyle(color: context.textPrimary,
                fontSize: 17, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: TextStyle(color: context.textSecondary,
                  fontSize: 14), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!, style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### `AppErrorState` — حالة خطأ موحَّدة

```dart
// lib/core/widgets/app_error_state.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class AppErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.errorSurface, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  size: 32, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message ?? 'حدث خطأ غير متوقع',
              style: TextStyle(color: context.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### `AppLoadingState` — حالة تحميل موحَّدة

```dart
// lib/core/widgets/app_loading_state.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class AppLoadingState extends StatelessWidget {
  final String? message;

  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: TextStyle(color: context.textSecondary, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}
```

### `AppSectionHeader` — عنوان قسم موحَّد

```dart
// lib/core/widgets/app_section_header.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: context.textPrimary,
            fontSize: 16, fontWeight: FontWeight.w700)),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!, style: const TextStyle(
                color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
```

### `AppInfoRow` — صف معلومات موحَّد

```dart
// lib/core/widgets/app_info_row.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class AppInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final bool isLast;

  const AppInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? context.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13)),
          ),
          Text(value, style: TextStyle(color: context.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

### `AppConfirmSheet` — تأكيد موحَّد

```dart
// lib/core/widgets/app_confirm_sheet.dart
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/widgets/app_button.dart';
import 'package:snapix/core/widgets/bottom_sheet_container.dart';

class AppConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDangerous;

  const AppConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'تأكيد',
    this.cancelLabel = 'إلغاء',
    this.isDangerous = false,
  });

  static Future<bool> show(BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool isDangerous = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppConfirmSheet(
        title: title, message: message,
        confirmLabel: confirmLabel, cancelLabel: cancelLabel,
        isDangerous: isDangerous,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: context.textPrimary,
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            text: confirmLabel,
            variant: isDangerous ? AppButtonVariant.danger : AppButtonVariant.primary,
            onPressed: () { Navigator.pop(context, true); onConfirm(); },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            text: cancelLabel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}
```

### `SharedTripCard` — بطاقة رحلة موحَّدة (User + Driver)

```dart
// lib/core/widgets/shared_trip_card.dart
/// يحل محل TripCard في user/trips/widgets + يُستخدم في driver/trips
/// يقبل isDriver لعرض واجهة مختلفة حسب الدور
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/utils/trip_status.dart';
import 'package:snapix/core/widgets/app_trip_status_chip.dart';

class SharedTripCard extends StatelessWidget {
  final String tripId;
  final TripStatus status;
  final String originAddress;
  final String destinationAddress;
  final String formattedDate;
  final String formattedPrice;
  final bool isDriver;
  final String? counterpartName;   // اسم المستخدم (للسائق) أو السائق (للمستخدم)
  final VoidCallback? onTap;
  final String Function(TripStatus) statusLabelBuilder;

  const SharedTripCard({
    super.key,
    required this.tripId,
    required this.status,
    required this.originAddress,
    required this.destinationAddress,
    required this.formattedDate,
    required this.formattedPrice,
    required this.statusLabelBuilder,
    this.isDriver = false,
    this.counterpartName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: AppSpacing.card,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: AppRadius.xl_,
          border: Border.all(color: context.divColor, width: .8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(formattedDate,
                      style: TextStyle(color: context.textSecondary, fontSize: 12)),
                ),
                AppTripStatusChip(status: status, labelBuilder: statusLabelBuilder),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _LocationRow(icon: Icons.radio_button_checked_rounded,
                color: AppColors.primary, address: originAddress),
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: Container(width: 2, height: 16,
                  decoration: BoxDecoration(color: context.divColor,
                      borderRadius: AppRadius.full_)),
            ),
            _LocationRow(icon: Icons.location_on_rounded,
                color: AppColors.error, address: destinationAddress),
            const SizedBox(height: AppSpacing.md),
            Divider(color: context.divColor, thickness: .6, height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (counterpartName != null)
                  Expanded(child: Text(counterpartName!,
                      style: TextStyle(color: context.textSecondary, fontSize: 13))),
                Text(formattedPrice,
                    style: const TextStyle(color: AppColors.primary,
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String address;
  const _LocationRow({required this.icon, required this.color, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(address,
            style: TextStyle(color: context.textPrimary, fontSize: 13,
                fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
```

---

## PART D — إصلاحات الأمان والبرمجة (الكاملة)

## 11. مشاكل الأمان [SEC] — الكود الكامل

### [SEC-01+02] إصلاح `cancel_trip` في DB

```sql
-- أضف هذا في أول دالة cancel_trip قبل أي منطق آخر:
CREATE OR REPLACE FUNCTION cancel_trip(
  p_trip_id UUID,
  p_user_id UUID,
  p_cancelled_by TEXT,
  p_cancel_reason TEXT DEFAULT NULL
) RETURNS void AS $$
DECLARE
  trip_record RECORD;
BEGIN
  -- [SEC-01] التحقق من قيمة p_cancelled_by أولاً
  IF p_cancelled_by NOT IN ('user', 'driver', 'system') THEN
    RAISE EXCEPTION 'cancel_trip: invalid cancelled_by value "%". Must be user|driver|system', p_cancelled_by;
  END IF;

  SELECT * INTO trip_record FROM trips WHERE id = p_trip_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'cancel_trip: trip % not found', p_trip_id;
  END IF;

  -- Authorization checks
  IF p_cancelled_by = 'user' AND trip_record.user_id != p_user_id THEN
    RAISE EXCEPTION 'cancel_trip: user not authorized to cancel trip %', p_trip_id;
  END IF;

  IF p_cancelled_by = 'driver' AND trip_record.driver_id != p_user_id THEN
    RAISE EXCEPTION 'cancel_trip: driver not authorized to cancel trip %', p_trip_id;
  END IF;

  -- [SEC-01 FIX] system cancel — فقط صاحب الرحلة يقدر يلغيها كـ system
  IF p_cancelled_by = 'system' AND trip_record.user_id != p_user_id THEN
    RAISE EXCEPTION 'cancel_trip: system cancel only allowed by trip owner. trip=%, caller=%', p_trip_id, p_user_id;
  END IF;

  -- باقي منطق الإلغاء...
  UPDATE trips SET
    status = 'cancelled',
    cancelled_by = p_cancelled_by,
    cancel_reason = p_cancel_reason,
    cancelled_at = NOW()
  WHERE id = p_trip_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### [SEC-02] إصلاح `searching_bloc.dart`

```dart
// في _onTick — بدل 'system' استخدم 'user'
'p_cancelled_by': 'user',  // المستخدم هو صاحب الرحلة في الحالتين
'p_cancel_reason': 'timeout',
```

### [SEC-03] إصلاح `complaints_repository.dart`

```dart
Future<void> submitComplaint({required String tripId, required String message}) async {
  final user = SupabaseService.currentUser;
  if (user == null) throw Exception('errorNotLoggedIn'); // ← أضف هذا
  await SupabaseService.client.from('complaints').insert({
    'user_id': user.id,   // ← مضمون لن يكون null
    'trip_id': tripId,
    'message': message,
    'status': 'open',
  });
}
```

### [SEC-04] إصلاح `user_presence_service.dart`

```dart
Future<void> startBroadcasting({double? lat, double? lng}) async {
  final resolvedLat = lat ?? _lastLat;
  final resolvedLng = lng ?? _lastLng;
  _isBroadcasting = true;

  if (resolvedLat == null || resolvedLng == null) {
    debugPrint('📡 UserPresence: No GPS fix yet — broadcasting armed, waiting for updateLocation()');
    // لا تكتب في DB — updateLocation() ستكتب عند أول قراءة GPS
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!_isBroadcasting || _lastLat == null) return;
      _upsertPresence(_lastLat!, _lastLng!);
    });
    return;
  }

  _lastLat = resolvedLat;
  _lastLng = resolvedLng;
  await _upsertPresence(_lastLat!, _lastLng!, force: true);

  _heartbeatTimer?.cancel();
  _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
    if (!_isBroadcasting || _lastLat == null) return;
    _upsertPresence(_lastLat!, _lastLng!);
  });
  debugPrint('📡 UserPresence: Broadcasting started at ($_lastLat, $_lastLng)');
}
```

---

## 12. الأخطاء الوظيفية [FL] — الكود الكامل

### [FL-01] إصلاح `TripOfferModel` — إضافة `proposedPrice`

```dart
// lib/core/models/trip_offer_model.dart
class TripOfferModel extends Equatable {
  final String id;
  final String tripId;
  final String driverId;
  final double? proposedPrice;   // ← أضف هذا
  // ... باقي الحقول

  factory TripOfferModel.fromJson(Map<String, dynamic> json) {
    return TripOfferModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      driverId: json['driver_id'] as String,
      proposedPrice: (json['proposed_price'] as num?)?.toDouble(), // ← أضف
      // ...
    );
  }

  @override
  List<Object?> get props => [id, tripId, driverId, proposedPrice]; // ← أضف
}
```

### [FL-02] إصلاح `MessagesCubit.initTripChat` — `canSend`

```dart
// في messages_cubit.dart، دالة initTripChat:
final active = AppConstants.activeTripStatuses.contains(status);
// ...
emit(state.copyWith(
  canSend: active,  // ← بدل 'canSend: true' المغلوطة
  // ...
));
```

### [FL-03] إصلاح `TripRouteCubit.addStopover` — emit خاطئ

```dart
// بعد نجاح createRoutePlanFromLegacy:
emit(state.copyWith(
  status: TripRouteStatus.loaded,  // ← بدل error
  errorMessage: null,              // ← امسح الرسالة
));
// يمكن استدعاء addStopover تلقائياً هنا لتجربة أسلس:
// unawaited(addStopover(stopoverId, stopoverLat, stopoverLng));
```

### [FL-09] إصلاح `FCMService._handledMessageIds` — FIFO بدل clear كلي

```dart
// في FCMService:
final List<String> _handledMessageIds = [];

bool _isAlreadyHandled(String? messageId) {
  if (messageId == null) return false;
  return _handledMessageIds.contains(messageId);
}

void _markAsHandled(String messageId) {
  if (_handledMessageIds.length >= 100) {
    _handledMessageIds.removeAt(0); // FIFO — أزل الأقدم
  }
  _handledMessageIds.add(messageId);
}

// [NEW-06] إصلاح notification ID:
int _notificationCounter = 0;
// في _showLocalNotification:
await _localNotifications.show(
  _notificationCounter++ % 1000, // دائماً فريد، يدور كل 1000
  notification.title,
  notification.body,
  details,
);
```

### [NEW-01] إصلاح `auth_bloc.dart` — `_onSignUpDriverRequested`

```dart
Future<void> _onSignUpDriverRequested(
  SignUpDriverRequested event,
  Emitter<AuthState> emit,
) async {
  if (state is AuthLoading) return;
  emit(AuthLoading());
  final result = await _authRepository.signUpDriver(/* ... */);
  await result.fold(  // ← await (كان result.fold بدون await)
    (error) async => emit(AuthError(error)),
    (user) async {
      await _storeFcmToken(user.id);  // ← أضف هذا — كل سائق جديد يحتاج FCM
      // لا startBroadcasting هنا — السائق غير verified بعد
      emit(AuthDriverPending(user));
    },
  );
}
```

### [NEW-02] إصلاح `FCMService._handleMessageOpen` — ride_offer navigation

```dart
case 'ride_offer':
  final tripId = message.data['trip_id'] as String?;
  final router = AppRouter.routerInstance; // ← تأكد من وجود static instance
  if (tripId != null) {
    // انتقل لتفاصيل الرحلة مباشرة
    router.go('${AppRoutes.driverTripDetails}?tripId=$tripId');
  } else {
    // fallback — انتقل للـ home حيث ستظهر الـ offer من خلال RideOfferBloc
    router.go(AppRoutes.driverHome);
  }
  break;
```

### [NEW-04] إصلاح `DirectionsService._cache` — تنظيف عند logout

في `auth_bloc.dart`، دالة `_onSignOutRequested`:
```dart
Future<void> _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) async {
  await UserPresenceService.instance.stopBroadcasting();
  await CellSubscriptionService.instance.dispose();
  HeatmapService.instance.dispose();
  LocationService.instance.stopAllTracking();
  DirectionsService.clearCache();          // ← أضف [NEW-04]
  FCMService().clearRideOfferHandler();    // ← أضف [NEW-02 arch]
  final result = await _authRepository.signOut();
  result.fold(
    (_) => emit(const AuthUnauthenticated()),
    (_) => emit(const AuthUnauthenticated()),
  );
}
```

---

## 13. مشاكل قاعدة البيانات [DB] — SQL الكامل الجاهز

### خطوة 1: ANALYZE فوراً

```sql
-- نفّذ كـ migration أو في Supabase SQL editor:
ANALYZE admin_logs;
ANALYZE app_config;
ANALYZE bonus_rules;
ANALYZE complaints;
ANALYZE coupon_audit_log;
ANALYZE coupon_usages;
ANALYZE coupons;
ANALYZE driver_bonus_ledger;
ANALYZE driver_revision_requests;
ANALYZE driver_service_areas;
ANALYZE driver_wallets;
ANALYZE pricing_config;
ANALYZE ratings;
ANALYZE service_areas;
ANALYZE trip_route_plans;
ANALYZE trip_route_waypoints;
ANALYZE user_coupons;
ANALYZE user_ratings;
ANALYZE user_wallets;
ANALYZE wallet_transactions;
ANALYZE withdrawal_requests;
```

### خطوة 2: VACUUM ANALYZE على الجداول المتضخمة

```sql
VACUUM ANALYZE users;
VACUUM ANALYZE vehicle_types;
VACUUM ANALYZE drivers_profile;
VACUUM ANALYZE trip_route_waypoints;
VACUUM ANALYZE driver_locations;
VACUUM ANALYZE driver_wallets;
VACUUM ANALYZE trip_offers;
VACUUM ANALYZE trips;
```

### خطوة 3: Indexes مفقودة

```sql
-- [DB-05] geohash على driver_locations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_driver_locations_geohash
  ON driver_locations(geohash);

-- [NEW] Index على trips.status للاستعلامات الأكثر تكراراً
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_status
  ON trips(status) WHERE status NOT IN ('completed', 'cancelled');

-- [NEW] Index على trips.user_id + status للمستخدمين
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_user_active
  ON trips(user_id, status) WHERE status NOT IN ('completed', 'cancelled');

-- [NEW] Index على trips.driver_id + status للسائقين
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_driver_active
  ON trips(driver_id, status) WHERE status NOT IN ('completed', 'cancelled');

-- [NEW] Index على trips.created_at للترتيب الزمني
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_created_at
  ON trips(created_at DESC);

-- [NEW] Index على notifications.user_id + is_read للبادجات
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_user_unread
  ON notifications(user_id, is_read) WHERE is_read = false;
```

### خطوة 4: إصلاح ratings UNIQUE constraint

```sql
-- تحقق من تكرار أولاً:
SELECT trip_id, COUNT(*) as cnt
FROM ratings
GROUP BY trip_id
HAVING COUNT(*) > 1;

-- إذا النتيجة فارغة (لا تكرار):
ALTER TABLE ratings DROP CONSTRAINT IF EXISTS uq_ratings_trip_user;
ALTER TABLE ratings ADD CONSTRAINT uq_ratings_trip UNIQUE (trip_id);
```

### خطوة 5: تعبئة pricing_config

```sql
INSERT INTO pricing_config (vehicle_type, base_fare, price_per_km, minimum_fare)
SELECT
  name AS vehicle_type,
  base_fare,
  price_per_km,
  minimum_fare
FROM vehicle_types
WHERE base_fare IS NOT NULL
ON CONFLICT (vehicle_type) DO UPDATE SET
  base_fare    = EXCLUDED.base_fare,
  price_per_km = EXCLUDED.price_per_km,
  minimum_fare = EXCLUDED.minimum_fare;
```

### خطوة 6: حذف Indexes غير المستخدمة (فوراً)

```sql
-- هذان المؤشران على أعمدة 100% NULL — لا فائدة منهما:
DROP INDEX IF EXISTS idx_trips_area;           -- service_area_id كله NULL
DROP INDEX IF EXISTS idx_trips_cancel_category; -- cancel_reason_category كله NULL
```

### خطوة 7: autovacuum tuning للجداول الساخنة (NEW)

```sql
-- user_presence: 110,344 writes — يحتاج vacuum أسرع
ALTER TABLE user_presence SET (
  autovacuum_vacuum_scale_factor = 0.01,   -- vacuum عند 1% dead rows (بدل 20%)
  autovacuum_analyze_scale_factor = 0.005,
  autovacuum_vacuum_cost_delay = 2         -- أسرع (ms)
);

-- trips: مهم وظيفياً
ALTER TABLE trips SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);

-- drivers_profile: 75% bloat
ALTER TABLE drivers_profile SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_vacuum_cost_delay = 5
);
```

### خطوة 8: حذف RLS policies المكررة

```sql
-- تحقق أولاً:
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('user_ratings', 'user_presence', 'coupon_usages')
ORDER BY tablename, cmd;

-- بعد مراجعة اليدوية:
DROP POLICY IF EXISTS p_ur_insert ON user_ratings;  -- إذا مكرر مع user_ratings_insert
DROP POLICY IF EXISTS p_ur_select ON user_ratings;  -- إذا مكرر مع user_ratings_select
DROP POLICY IF EXISTS p_up_select ON user_presence; -- راجع أولاً
-- لا تحذف بدون مراجعة الـ USING clause لكل سياسة
```

---

## PART E — خطة تحسين الأداء الشاملة

## 15. أداء Flutter — BLoC + Streams + UI

### [PERF-FL-01] تقليل إعادة البناء غير الضرورية في BLoC

```dart
// بدل BlocBuilder<MyBloc, MyState> بدون شرط:
BlocBuilder<MyBloc, MyState>(
  buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType, // بناء عند تغيير النوع فقط
  builder: (context, state) { ... },
)

// للحالات المعقدة:
BlocSelector<DriverHomeBloc, DriverHomeState, bool>(
  selector: (state) => state is DriverHomeLoaded,
  builder: (context, isLoaded) { ... },
)
```

### [PERF-FL-02] Lazy Loading للـ Screens الثقيلة

الـ screens التالية تتجاوز 45,000 بايت — تحتاج lazy initialization:
- `UserTripDetailsScreen` (82,199 bytes)
- `LocationSelectionScreen` (81,112 bytes)
- `UserHomeScreen` (49,909 bytes)
- `TrackingScreen` (45,599 bytes)

```dart
// في app_router.dart — استخدم builder بدل redirect لتأخير التهيئة:
GoRoute(
  path: AppRoutes.userTripDetails,
  builder: (context, state) {
    // يُبنى فقط عند الانتقال الفعلي
    return const UserTripDetailsScreen();
  },
),
```

### [PERF-FL-03] `StatCard` — استخدام `const` بشكل صحيح

```dart
// StatCard لا يتغير — استخدم const في الاستدعاء:
const StatCard(label: 'الرحلات', value: '12', icon: Icons.directions_car_rounded)
```

### [PERF-FL-04] Image Caching Strategy

```dart
// في main() — ضبط CachedNetworkImage cache:
CachedNetworkImage.logLevel = CacheManagerLogLevel.none; // في Production

// ضبط PaintingBinding لحجم cache الصور:
PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB
PaintingBinding.instance.imageCache.maximumSize = 200; // 200 صورة
```

### [PERF-FL-05] تجنب `withValues(alpha:)` المتكرر — استخدم الثوابت

```dart
// بدل تكرار هذا في كل widget:
AppColors.black.withValues(alpha: 0.18) // ← يُنشئ Color جديدة في كل build

// في AppColors، أضف:
static final blackOverlay08  = Colors.black.withValues(alpha: 0.08);
static final blackOverlay18  = Colors.black.withValues(alpha: 0.18);
static final blackOverlay24  = Colors.black.withValues(alpha: 0.24);
static final primaryOverlay38 = AppColors.primary.withValues(alpha: 0.38);
```

---

## 16. أداء قاعدة البيانات — أعمق من v4

### [PERF-DB-01] pg_stat_statements — اكتشاف أبطأ الاستعلامات

```sql
-- تشغيل أسبوعياً — يُظهر أبطأ 20 استعلام:
SELECT
  LEFT(query, 100) AS query_preview,
  calls,
  ROUND(total_exec_time::numeric, 2) AS total_ms,
  ROUND((total_exec_time/calls)::numeric, 2) AS avg_ms,
  ROUND(stddev_exec_time::numeric, 2) AS stddev_ms
FROM pg_stat_statements
WHERE calls > 10
ORDER BY avg_ms DESC
LIMIT 20;
```

### [PERF-DB-02] Connection Pooling — مراجعة إعدادات Supabase

```
الإعداد الموصى به لمرحلة pre-production (أقل من 100 مستخدم نشط):
- Pool Mode: Transaction (لا Session)
- Pool Size: 15 connections
- Max Client Connections: 100

عند نمو التطبيق (500+ مستخدم):
- Pool Mode: Transaction
- Pool Size: 25
- Max Client Connections: 500
```

### [PERF-DB-03] user_presence — تقليل write load

الحالي: 110,344 writes/session. مع Haversine 50m filter — جيد حالياً.

**عند 1000+ مستخدم نشط:**
```dart
// في user_presence_service.dart — أضف jitter لمنع thundering herd:
static const Duration _heartbeatInterval = Duration(seconds: 60);
static const int _jitterSeconds = 15; // ± 15 ثانية عشوائية

_heartbeatTimer = Timer.periodic(
  Duration(seconds: 60 + Random().nextInt(_jitterSeconds * 2) - _jitterSeconds),
  (_) => { ... }
);
```

### [PERF-DB-04] trips — Partial Index للاستعلامات الأكثر تكراراً

```sql
-- استعلام "رحلاتي النشطة" — يحدث مئات المرات يومياً:
-- SELECT * FROM trips WHERE user_id = $1 AND status NOT IN ('completed','cancelled')
-- الـ partial index يجعله instant:
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trips_user_active
  ON trips(user_id)
  WHERE status NOT IN ('completed', 'cancelled');  -- partial: rows قليلة فقط
```

---

## 17. أداء الشبكة — Caching + Adaptive Polling

### [PERF-NET-01] `DirectionsService` — رفع الـ cache limit

```dart
// directions_service.dart
static const int _maxCacheSize = 100; // رفع من 50 إلى 100 (رحلات أكثر)
static const Duration _cacheTtl = Duration(minutes: 10); // رفع من 5 إلى 10 دقائق
// (المسارات لا تتغير خلال 10 دقائق في الغالب)
```

### [PERF-NET-02] `CellSubscriptionService` — Adaptive interval

```dart
// بدل polling ثابت 5 ثوانٍ:
// عند السائق ساكن: كل 10 ثوانٍ
// عند السائق متحرك: كل 5 ثوانٍ
Duration get _currentInterval {
  if (_lastDriverCount == 0) return const Duration(seconds: 10); // لا سائقين — أبطأ
  return const Duration(seconds: 5); // سائقون موجودون — عادي
}
```

### [PERF-NET-03] `AppConfigRepository` — Cache أطول

```dart
// حالياً لا يوجد TTL واضح — أضف:
static const Duration _configCacheTtl = Duration(minutes: 30);
// app_config لا يتغير كثيراً — لا تحتاج تحديث كل startBroadcasting
```

---

## 18. معمارية النظام — الإضافات الكبيرة

### [ARCH-01] `LogoutCoordinator` — تنسيق الـ logout (مفهوم جديد كلياً)

المشكلة الحالية: `AuthBloc._onSignOutRequested` مسؤول عن استدعاء كل الـ services للتنظيف — هذا يجعله يعرف بـ implementation details لكل service.

```dart
// lib/core/services/logout_coordinator.dart ← ملف جديد
import 'package:snapix/services/user_presence_service.dart';
import 'package:snapix/services/cell_subscription_service.dart';
import 'package:snapix/services/heatmap_service.dart';
import 'package:snapix/services/location_service.dart';
import 'package:snapix/services/directions_service.dart';
import 'package:snapix/services/fcm_service.dart';

/// مسؤول عن تنسيق تنظيف كل الـ services عند logout
/// AuthBloc يستدعي LogoutCoordinator فقط — لا يعرف تفاصيل كل service
class LogoutCoordinator {
  static final LogoutCoordinator instance = LogoutCoordinator._();
  LogoutCoordinator._();

  /// قائمة الـ callbacks المسجّلة من كل service
  final List<Future<void> Function()> _cleanupCallbacks = [];

  /// كل service يسجّل نفسه هنا في initialize()
  void register(Future<void> Function() cleanup) {
    _cleanupCallbacks.add(cleanup);
  }

  /// يُستدعى من AuthBloc عند logout فقط
  Future<void> performLogout() async {
    await Future.wait(
      _cleanupCallbacks.map((fn) => fn().catchError((e) {
        debugPrint('⚠️ LogoutCoordinator: cleanup failed — $e');
      })),
    );
    _cleanupCallbacks.clear();
    debugPrint('✅ LogoutCoordinator: all services cleaned up');
  }
}

// الاستخدام في AuthBloc:
Future<void> _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) async {
  await LogoutCoordinator.instance.performLogout(); // ← سطر واحد يكفي
  final result = await _authRepository.signOut();
  result.fold(
    (_) => emit(const AuthUnauthenticated()),
    (_) => emit(const AuthUnauthenticated()),
  );
}

// في كل service — سجّل نفسك:
// مثلاً في UserPresenceService:
void _initializeLogoutCleanup() {
  LogoutCoordinator.instance.register(() => stopBroadcasting());
}

// في DirectionsService:
void _initializeLogoutCleanup() {
  LogoutCoordinator.instance.register(() async => clearCache());
}
```

### [ARCH-02] `FCMService` — Callback Pattern (فصل كامل)

```dart
// lib/services/fcm_service.dart — بدل import من features/presentation/

class FCMService {
  // ... existing code ...

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Callback Registry — بدل direct import
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  void Function(Map<String, dynamic>)? _onRideOffer;
  void Function(String tripId)? _onTripUpdate;
  void Function(String conversationId)? _onNewMessage;

  void setRideOfferHandler(void Function(Map<String, dynamic>) handler) {
    _onRideOffer = handler;
  }

  void setTripUpdateHandler(void Function(String) handler) {
    _onTripUpdate = handler;
  }

  void setNewMessageHandler(void Function(String) handler) {
    _onNewMessage = handler;
  }

  void clearRideOfferHandler() => _onRideOffer = null;

  // في _handleForegroundMessage:
  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'];
    switch (type) {
      case 'ride_offer':
        _onRideOffer?.call(message.data); // ← callback بدل direct widget call
        break;
      // ...
    }
  }
}

// في DriverHomeScreen.initState():
@override
void initState() {
  super.initState();
  FCMService().setRideOfferHandler(_handleRideOffer); // ← يُسجَّل هنا
}

@override
void dispose() {
  FCMService().clearRideOfferHandler(); // ← يُلغى هنا
  super.dispose();
}

void _handleRideOffer(Map<String, dynamic> data) {
  // عرض RideOfferOverlay
  context.read<RideOfferBloc>().add(RideOfferReceived(data));
}
```

### [ARCH-03] `HeatmapService` — توثيق قرار الـ Realtime

```dart
// heatmap_service.dart — أضف هذا التعليق بوضوح:

/// ملاحظة معمارية: HeatmapService تستخدم Realtime مباشرة على user_presence
/// وهذا يبدو متناقضاً مع CellSubscriptionService التي تستخدم polling.
///
/// السبب: user_presence لا يحتوي national_id أو بيانات حساسة.
/// RLS policy على user_presence Realtime تقيّد التدفق لـ authenticated users فقط.
/// المخاطر: منخفضة — المستخدم يرى مواقع مجهولة (lat/lng) بدون معرّفات.
///
/// إذا أردت الاتساق الكامل: استبدل بـ Timer.periodic + RPC poll.
/// تم اختيار Realtime هنا لأن heatmap data خفيفة وتحديث مستمر مقبول.
void _subscribeToRealtime() { ... }
```

---

## PART F — خطة التنفيذ

## 19. مصفوفة المخاطر الكاملة الموحَّدة (v5)

| ID | الأولوية | المشكلة | الخطورة | وقت الإصلاح |
|----|---------|---------|---------|------------|
| SEC-01 | **P0** | cancel_trip auth bypass | CRITICAL | 15 دقيقة |
| SEC-02 | **P0** | SearchingBloc 'system' | CRITICAL | 2 دقيقة |
| NEW-01 | **P0** | SignUpDriver بدون FCM | HIGH | 10 دقيقة |
| SEC-03 | **P0** | complaints null user_id | HIGH | 2 دقيقة |
| SEC-04 | **P0** | UserPresence (0,0) write | HIGH | 20 دقيقة |
| DB-01 | **P0** | 21 جدول بدون ANALYZE | HIGH | 1 دقيقة (SQL) |
| DB-02 | **P0** | Bloat 25-75% على 8 جداول | HIGH | 2 دقيقة (SQL) |
| V5-02 | **P1** | AppToast.error بلون خاطئ | HIGH | 1 دقيقة |
| V5-01 | **P1** | lightTheme = darkTheme | HIGH | ساعة |
| NEW-02 | **P1** | FCM ride_offer tap فارغ | HIGH | 30 دقيقة |
| FL-01 | **P1** | TripOfferModel ناقص price | HIGH | 30 دقيقة |
| FL-02 | **P1** | canSend دائماً true | HIGH | 2 دقيقة |
| V5-03 | **P1** | Double imports × 4 ملفات | MEDIUM | 5 دقائق |
| FL-07 | **P1** | FCMService import انعكاس | HIGH | يوم |
| NEW-05 | **P1** | LocationService void tracking | MEDIUM | ساعة |
| DB-03 | **P1** | ratings UNIQUE خاطئ | MEDIUM | ساعة |
| DB-04 | **P1** | pricing_config فارغة | MEDIUM | 5 دقائق (SQL) |
| FL-05 | **P1** | admin_reply لا تظهر | MEDIUM | ساعة |
| V5-04 | **P2** | ThemeBloc Flash of Theme | MEDIUM | 30 دقيقة |
| NEW-03 | **P2** | HeatmapService inconsistency | MEDIUM | ساعة |
| NEW-04 | **P2** | DirectionsService cache leak | MEDIUM | 5 دقائق |
| FL-03 | **P2** | addStopover emit error | HIGH | 30 دقيقة |
| FL-08 | **P2** | _broadcastedDriverIds unused | MEDIUM | ساعة |
| FL-09 | **P2** | _handledMessageIds clear كلي | MEDIUM | 30 دقيقة |
| DB-05 | **P2** | Missing geohash index | MEDIUM | دقيقة (SQL) |
| V5-05 | **P2** | main.dart 10 أسطر فارغة | LOW | دقيقة |
| V5-06 | **P2** | ConnectivityService unawaited | LOW | دقيقة |
| V5-07 | **P2** | AppButton بدون haptic | LOW | 5 دقائق |
| FL-04 | **P2** | DriverRevisionScreen مفقودة | MEDIUM | يومان |
| DB-06 | **P2** | 5 RLS policies مكررة | LOW | ساعة |
| RT-01 | **P2** | wallet_id vs userId | MEDIUM | ساعة |
| NEW-06 | **P3** | notification hashCode collision | LOW | 15 دقيقة |
| V5-08 | **P3** | AppCachedImage magic number 8 | LOW | دقيقة |
| V5-09 | **P3** | defaultMapCenter hardcoded | LOW | ساعة |
| FL-06 | **P3** | UserWalletScreen بدون Cubit | MEDIUM | يوم |
| FL-10 | **P3** | _payloadSub وهمي | LOW | ساعة |
| RT-02 | **P3** | PresenceService race | LOW | ساعة |
| DB-07 | **P4** | 23 unused indexes (انتظر) | LOW | انتظر 30 يوم |

---

## 20. خطة الإصلاح المرحلية الكاملة

### 🔴 المرحلة 0 — P0: Security + DB حرج (اليوم الأول، ساعتان)

**خطوة 1 — DB (15 دقيقة):**
```sql
-- نفّذ بالترتيب في Supabase SQL Editor:
-- 1. إصلاح cancel_trip (أهم شيء)
-- 2. ANALYZE على 21 جدول
-- 3. VACUUM ANALYZE على 8 جداول
-- 4. حذف idx_trips_area + idx_trips_cancel_category
-- (الكود الكامل في القسم 13 أعلاه)
```

**خطوة 2 — Flutter (45 دقيقة):**
```dart
// بالترتيب:
// 1. searching_bloc.dart: 'system' → 'user' (2 دقيقة)
// 2. complaints_repository.dart: إضافة null check (2 دقيقة)
// 3. user_presence_service.dart: إصلاح (0,0) write (20 دقيقة)
// 4. auth_bloc.dart: إضافة _storeFcmToken لـ SignUpDriver (5 دقيقة)
// 5. app_toast.dart: error → AppColors.error (1 دقيقة)
// 6. Double imports × 4 ملفات (5 دقيقة)
```

---

### 🟠 المرحلة 1 — P1: Bugs وظيفية (الأسبوع الأول، 3-4 أيام)

**الثلاثاء — Flutter:**
- [ ] `fcm_service.dart`: إصلاح ride_offer navigation
- [ ] `trip_offer_model.dart`: إضافة proposedPrice
- [ ] `messages_cubit.dart`: canSend: active
- [ ] `trip_route_cubit.dart`: إصلاح emit خاطئ

**الأربعاء — DB:**
- [ ] pricing_config: تعبئة من vehicle_types
- [ ] ratings: إصلاح UNIQUE constraint
- [ ] Indexes الجديدة: trips.status, notifications.unread

**الخميس — Design System:**
- [ ] إنشاء `app_spacing.dart`
- [ ] إنشاء `app_radius.dart`
- [ ] إنشاء `app_text_styles.dart`
- [ ] إنشاء `app_shadows.dart`
- [ ] تحديث `app_theme.dart` (إصلاح lightTheme + استخدام الثوابت الجديدة)
- [ ] تحديث `theme_extensions.dart`

**الجمعة — Widgets الجديدة (بالأولوية):**
- [ ] `AppTextField`
- [ ] `AppCard`
- [ ] `AppEmptyState`
- [ ] `AppErrorState`
- [ ] `AppLoadingState`
- [ ] `AppBadge`
- [ ] `AppTripStatusChip`

---

### 🟡 المرحلة 2 — P2: تحسينات (الأسبوع 2-3)

**Widgets إضافية:**
- [ ] `AppAvatar`
- [ ] `AppSectionHeader`
- [ ] `AppInfoRow`
- [ ] `AppConfirmSheet`
- [ ] `SharedTripCard` (يحل محل TripCard المتفرقة)

**معمارية:**
- [ ] `LogoutCoordinator` — تنسيق cleanup
- [ ] FCMService Callback Pattern — فصل عن presentation
- [ ] HeatmapService — توثيق القرار المعماري
- [ ] DirectionsService.clearCache() في logout

**تنظيف:**
- [ ] حذف Dead Code: `trip_event.dart`, `trip_state.dart`, `user_drawer.dart`, `user_profile_repository.dart`
- [ ] حذف مجلد `lib/features/driver/presentation/revision/` الفارغ (أو تعبئته بـ DriverRevisionScreen)
- [ ] إصلاح ThemeBloc Flash of Theme
- [ ] ConnectivityService: إضافة await
- [ ] AppButton: إضافة haptic

---

### 🟢 المرحلة 3 — P3: ملاحظات تقنية (الأسبوع 4+)

- [ ] `DriverRevisionRequestsScreen` — إنشاء شاشة كاملة
- [ ] `ComplaintsScreen` — إضافة admin_reply
- [ ] `UserWalletCubit` — فصل عن الـ local state
- [ ] UserPresence heartbeat jitter (للاستعداد للـ scale)
- [ ] pg_stat_statements — مراجعة أولى بعد launch
- [ ] autovacuum tuning للجداول الساخنة
- [ ] V5-09: defaultMapCenter → app_config

---

### ⚪ المرحلة 4 — P4: بعد 30 يوم من Launch

- [ ] مراجعة 23 unused indexes بعد traffic حقيقي
- [ ] Connection pooling settings بناءً على الحمل الفعلي
- [ ] DirectionsService cache size review
- [ ] قرار معماري: هل نكمل Clean Architecture أم نحذف abstract layers الفارغة؟

---

## 21. Dead Code الكامل — ملفات يجب حذفها أو إكمالها

### احذف فوراً (مؤكد بـ grep)

| الملف | الدليل | الإجراء |
|-------|-------|---------|
| `lib/features/trips/presentation/bloc/trip_event.dart` | صفر imports | احذف |
| `lib/features/trips/presentation/bloc/trip_state.dart` | صفر imports | احذف |
| `lib/features/user/presentation/home/widgets/user_drawer.dart` | تعريف فقط، AppDrawer هو المستخدم | احذف |
| `lib/features/user/domain/repositories/user_profile_repository.dart` | محتواه comment فقط | احذف |

### أكمل أو احذف (مجلدات فارغة)

| المجلد | الإجراء المقترح |
|--------|----------------|
| `lib/features/driver/presentation/revision/` | أنشئ `DriverRevisionScreen` (P2) |
| `lib/features/trips/domain/` | إما أكمل `TripRepositoryImpl` أو احذف الـ abstract layer |

### توحيد (تكرار وظيفي)

| المشكلة | الحل |
|---------|------|
| `RideOfferModel` + `TripOfferModel` | وحّدهما بعد إضافة tests لكلاهما (P4) |
| `TripCard` (user) + بطاقة السائق | استخدم `SharedTripCard` الجديد (P2) |
| 8+ Empty/Error states مختلفة | استخدم `AppEmptyState` و`AppErrorState` (P2) |

---

## 22. الملاحظات المعمارية النهائية

### ملف الـ Exports الموحَّد لنظام التصميم

أنشئ ملف واحد يُوحَّد به كل نظام التصميم:

```dart
// lib/core/theme/design_system.dart ← ملف جديد
/// نظام التصميم الموحَّد — استورد هذا الملف بدل استيراد كل ملف على حدة
export 'package:snapix/core/theme/app_colors.dart';
export 'package:snapix/core/theme/app_spacing.dart';
export 'package:snapix/core/theme/app_radius.dart';
export 'package:snapix/core/theme/app_text_styles.dart';
export 'package:snapix/core/theme/app_shadows.dart';
export 'package:snapix/core/theme/app_theme.dart';
export 'package:snapix/core/theme/theme_extensions.dart';
```

ثم في أي screen:
```dart
import 'package:snapix/core/theme/design_system.dart'; // ← import واحد للكل
```

### ملف الـ Exports لـ Widgets

```dart
// lib/core/widgets/widgets.dart ← ملف جديد
export 'package:snapix/core/widgets/app_button.dart';
export 'package:snapix/core/widgets/app_text_field.dart';
export 'package:snapix/core/widgets/app_card.dart';
export 'package:snapix/core/widgets/app_avatar.dart';
export 'package:snapix/core/widgets/app_badge.dart';
export 'package:snapix/core/widgets/app_trip_status_chip.dart';
export 'package:snapix/core/widgets/app_empty_state.dart';
export 'package:snapix/core/widgets/app_error_state.dart';
export 'package:snapix/core/widgets/app_loading_state.dart';
export 'package:snapix/core/widgets/app_section_header.dart';
export 'package:snapix/core/widgets/app_info_row.dart';
export 'package:snapix/core/widgets/app_confirm_sheet.dart';
export 'package:snapix/core/widgets/shared_trip_card.dart';
export 'package:snapix/core/widgets/app_cached_image.dart';
export 'package:snapix/core/widgets/bottom_sheet_container.dart';
export 'package:snapix/core/widgets/map_button.dart';
export 'package:snapix/core/widgets/stat_card.dart';
export 'package:snapix/core/widgets/app_drawer.dart';
```

### نقطة القوة: ما يبقى كما هو (لا تلمسه)

| المكوّن | السبب |
|---------|-------|
| `CellSubscriptionService` polling 5ث | قرار أمان مدروس — يحمي national_id |
| `driver_accept_trip: FOR UPDATE SKIP LOCKED` | منع race condition — لا تغيّر |
| `validate_trip_status_transition` trigger | حماية server-side قوية |
| `withRetry` Exponential Backoff | مطبَّق بشكل صحيح |
| `cleanup_stale_user_presence` pg_cron | نظّفت 1,835 مرة — تعمل ممتاز |
| `TripRouteCubit` Optimistic Updates | منطق ذكي + تراجع عند الفشل |
| `MessagesCubit` Deduplication | ذكي — احتفظ به |
| `AppConfigRepository` non-blocking | startup صحيح |
| `AuthRepositoryImpl` Auto-Recovery | يحل PGRST116 تلقائياً |

### الخلاصة النهائية

بعد تطبيق هذا التقرير، Snapix Taxi ستصبح:

```
✅ أمان:        صفر ثغرات مؤكدة
✅ قاعدة بيانات: محسَّنة بالكامل (ANALYZE + indexes + autovacuum)
✅ نظام تصميم:  5 ملفات موحَّدة (Colors + Spacing + Radius + TextStyles + Shadows)
✅ مكتبة Widgets: 23 widget موحَّدة (قابلة للاختبار، قابلة للتغيير)
✅ معمارية:     FCM decoupled + LogoutCoordinator + Dead Code محذوف
✅ أداء:        DB محسَّن + Adaptive polling + Image cache strategy
✅ تجربة مطوّر: import واحد للـ design system + import واحد للـ widgets
```

---

## ملخص الاكتشافات الجديدة الحصرية لـ v5

### اكتشافات من الكود المباشر (لم تُذكر في v4 OMEGA)

| ID | المشكلة | الخطورة | الملف |
|----|---------|---------|-------|
| **V5-01** | `lightTheme` يُعيد `darkTheme` — لا Light Mode حقيقي | 🔴 HIGH | `app_theme.dart` |
| **V5-02** | `AppToast.error()` بخلفية زرقاء بدل حمراء | 🔴 HIGH | `app_toast.dart` |
| **V5-03** | Double Import × 4 ملفات (app_colors مرتين) | 🟠 HIGH | 4 ملفات |
| **V5-04** | ThemeBloc: Flash of Wrong Theme عند startup | 🟠 MEDIUM | `theme_bloc.dart` |
| **V5-05** | `main.dart`: 10 أسطر فارغة (dead code remnants) | 🟡 LOW | `main.dart` |
| **V5-06** | `ConnectivityService.init()` بدون await أو catchError | 🟡 MEDIUM | `main.dart` |
| **V5-07** | `AppButton`: بدون Haptic Feedback | 🟡 LOW | `app_button.dart` |
| **V5-08** | `AppCachedImage`: magic number `8` بدل `AppRadius.sm` | 🟢 LOW | `app_cached_image.dart` |
| **V5-09** | `defaultMapCenter` ثابت hardcoded — لا يدعم multi-city | 🟢 LOW | `app_constants.dart` |

### إضافات هيكلية (غير موجودة في الكود الحالي)

| الإضافة | القيمة |
|---------|--------|
| `AppSpacing` | 8 قيم موحَّدة + EdgeInsets جاهزة |
| `AppRadius` | 9 قيم موحَّدة + BorderRadius جاهزة |
| `AppTextStyles` | 20+ style موحَّدة بنظام Type Scale |
| `AppShadows` | 6 ظلال جاهزة (بدل تكرار BoxShadow) |
| `AppTheme.lightTheme` (حقيقي) | Light Mode يعمل فعلاً |
| `AppColors` (محسَّنة) | Light/Dark variants + semantic trip colors |
| `design_system.dart` export | import واحد لكل نظام التصميم |
| `widgets.dart` export | import واحد لكل الـ widgets |
| 15 Widget جديد | بطاقات، حالات، أزرار، تأكيدات موحَّدة |
| `LogoutCoordinator` | تنسيق cleanup معماري (مفهوم جديد) |

---

*نهاية تقرير ULTRA v5*

*المصادر: 184 ملف Dart + 292 ملف في lib.zip + CSV Schema Introspection كامل (3007 سطر)*
*يتجاوز: v1 + v2-Corrected + v3 + Ultimate + v4 OMEGA*
*الإضافات الحصرية لـ v5: 9 اكتشافات جديدة + نظام تصميم كامل + 15 widget + LogoutCoordinator + FCM Decoupling + DB Deeper + Light Theme*
*التاريخ: 2026-05-16*
