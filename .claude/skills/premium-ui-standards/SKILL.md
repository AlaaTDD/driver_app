---
name: Premium UI/UX Standards
description: >
  يُفعَّل عند بناء أو تعديل أي شاشة، widget، أو مكوّن UI.
  يضمن تصميماً premium متسقاً باستخدام Design System الكامل للمشروع.
  مكمّل إلزامي لـ taxi-app-architecture.
---

# Premium UI/UX Standards

> كل شاشة يجب أن تبدو احترافية في 3 ثوانٍ الأولى.
> بلا ألوان hardcoded، بلا loading بدائي، بلا حالات فارغة مهملة.

---

## §1 Design System — نقطة الاستيراد الوحيدة

```dart
// ✅ هذا الـ import الوحيد الذي تحتاجه لنظام التصميم كاملاً
import 'package:snapix/core/theme/design_system.dart';
```

---

## §2 نظام الألوان الكامل

### الألوان الثابتة (للعلامة التجارية والحالات)
```dart
// ── Brand ──
AppColors.primary       = Color(0xFF4C8BF5)  // أزرق رئيسي
AppColors.primaryDark   = Color(0xFF3868C0)  // hover/pressed
AppColors.primaryLight  = Color(0xFF93C5FD)  // subtle
AppColors.secondary     = Color(0xFF1FC87A)  // أخضر القبول

// ── Semantic ──
AppColors.success       = Color(0xFF1FC87A)  // completed, online
AppColors.error         = Color(0xFFFF4060)  // failed, rejected
AppColors.warning       = Color(0xFFF5A524)  // pending, attention
AppColors.info          = Color(0xFF3B82F6)  // informational

// ── Semantic Surfaces (20% opacity جاهزة) ──
AppColors.successSurface = Color(0x331FC87A)
AppColors.errorSurface   = Color(0x33FF4060)
AppColors.warningSurface = Color(0x33F5A524)
AppColors.infoSurface    = Color(0x333B82F6)
AppColors.primarySurface20 = Color(0x334C8BF5)

// ── Gradients جاهزة ──
AppColors.primaryGradient   // أزرق: primary → primaryDark
AppColors.successGradient   // أخضر: secondary → secondaryDark
AppColors.backgroundGradient // خلفية: background → surface
```

### الألوان الديناميكية (تتكيف مع Dark/Light)
```dart
// Dark Mode              Light Mode
context.bgColor          // #070C18    #F8FAFC
context.cardColor        // #181C2A    #FFFFFF
context.elevatedColor    // #1E2336    #F1F5F9
context.divColor         // #252A3D    #E2E8F0
context.sheetColor       // #12151F    #FFFFFF
context.textPrimary      // #EEF0FF    #0F172A
context.textSecondary    // #7B82A3    #64748B
context.textDisabled     // #3A4060    #94A3B8

// ✅ ALWAYS ديناميكية في أي widget
// ❌ NEVER hardcoded dark/light
color: isDark ? Color(0xFF181C2A) : Colors.white  // ← ممنوع!
```

### قاعدة Opacity — لا `withOpacity` أبداً
```dart
// ✅ CORRECT
color: AppColors.primary.withValues(alpha: 0.2)
color: AppColors.primarySurface20   // جاهز مسبقاً!

// ❌ WRONG (deprecated)
color: AppColors.primary.withOpacity(0.2)
```

---

## §3 نظام الطباعة

```dart
// ── Display (32-24px) — Hero sections ──
context.ts.displayLg   // 32px w800 — شاشات الترحيب
context.ts.displayMd   // 28px w800
context.ts.displaySm   // 24px w700

// ── Headline (22-18px) — عناوين الشاشات ──
context.ts.headlineLg  // 22px w700
context.ts.headlineMd  // 20px w700
context.ts.headlineSm  // 18px w700  ← عنوان AppBar الافتراضي

// ── Title (17-13px) — عناوين الكروت ──
context.ts.titleLg     // 17px w700
context.ts.titleMd     // 15px w600  ← عنوان الكارت
context.ts.titleSm     // 13px w600

// ── Body (16-13px) — النصوص ──
context.ts.bodyLg      // 16px w400
context.ts.bodyMd      // 14px w400  ← النص الافتراضي
context.ts.bodySm      // 13px w400

// ── Label (16-11px) — الأزرار والشارات ──
context.ts.labelLg     // 16px w700
context.ts.labelMd     // 14px w600
context.ts.labelSm     // 12px w600  ← نصوص الأزرار الصغيرة
context.ts.labelXs     // 11px w500

// ── Caption (12-11px) — النصوص الثانوية ──
context.ts.captionMd   // 12px w400  ← تاريخ، تفاصيل ثانوية
context.ts.captionSm   // 11px w400

// ── Price (28-16px) — tabular figures ──
context.ts.priceLg     // 28px w800  ← سعر رئيسي كبير
context.ts.priceMd     // 20px w700
context.ts.priceSm     // 16px w600

// تطبيق لون:
Text('عنوان', style: context.ts.headlineSm.colored(context.textPrimary))
// تعديل وزن:
context.ts.bodyMd.bold      // w700
context.ts.bodyMd.semibold  // w600
context.ts.bodyMd.sized(15) // fontSize 15
```

---

## §4 نظام المسافات

```dart
// ── Tokens ──
AppSpacing.xs  = 4.0
AppSpacing.sm  = 8.0
AppSpacing.md  = 12.0
AppSpacing.lg  = 16.0
AppSpacing.xl  = 20.0
AppSpacing.xxl = 24.0
AppSpacing.xxxl= 32.0
AppSpacing.huge= 48.0

// ── SizedBox جاهزة ──
AppSpacing.vXs   AppSpacing.vSm   AppSpacing.vMd   AppSpacing.vLg
AppSpacing.vXl   AppSpacing.vXxl  AppSpacing.vXxxl AppSpacing.vHuge
AppSpacing.hXs   AppSpacing.hSm   AppSpacing.hMd   AppSpacing.hLg

// ── EdgeInsets جاهزة ──
AppSpacing.screenH  // horizontal: 20 ← للشاشات
AppSpacing.screen   // LTRB(20,16,20,32) ← padding كامل
AppSpacing.card     // all: 16 ← padding الكروت
AppSpacing.cardLg   // all: 20
AppSpacing.sheet    // LTRB(20,16,20,34) ← bottom sheets
AppSpacing.chip     // H:12 V:4 ← chips صغيرة
AppSpacing.btnSm    // H:16 V:8
AppSpacing.btnMd    // H:20 V:12
AppSpacing.btnLg    // H:24 V:15 ← للأزرار الكبيرة
AppSpacing.inputV   // H:16 V:12 ← حقول الإدخال

// ✅ ALWAYS — استخدم tokens
Padding(padding: AppSpacing.card)
SizedBox(height: AppSpacing.lg)
// ❌ NEVER — hardcoded
Padding(padding: EdgeInsets.all(16))
SizedBox(height: 16)
```

---

## §5 نظام الزوايا

```dart
// ── BorderRadius جاهزة ──
AppRadius.xs_   = BorderRadius.circular(6)
AppRadius.sm_   = BorderRadius.circular(8)
AppRadius.md_   = BorderRadius.circular(12)
AppRadius.lg_   = BorderRadius.circular(14)
AppRadius.xl_   = BorderRadius.circular(16)  ← الكروت
AppRadius.xxl_  = BorderRadius.circular(20)  ← أزرار كبيرة
AppRadius.xxxl_ = BorderRadius.circular(24)
AppRadius.huge_ = BorderRadius.circular(32)
AppRadius.full_ = BorderRadius.circular(100) ← chips/avatars

// ── أشكال خاصة ──
AppRadius.sheetTop   // زوايا علوية فقط (xxxl) ← bottom sheets
AppRadius.sheetTopXl // زوايا علوية (huge)
AppRadius.cardBottom // زوايا سفلية فقط (xl)
AppRadius.cardTop    // زوايا علوية فقط (xl)
```

---

## §6 معايير كل شاشة — إلزامية

### قالب تصميم الكارت
```dart
Container(
  margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
  padding: AppSpacing.card,
  decoration: BoxDecoration(
    color: context.cardColor,                    // ✅ ديناميكي
    borderRadius: AppRadius.xl_,                 // ✅ 16px
    border: Border.all(color: context.divColor, width: 1),
    boxShadow: [
      BoxShadow(
        color: AppColors.black.withValues(alpha: 0.04),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  ),
)
```

### الحالات الإلزامية لكل شاشة
```dart
// ✅ كل شاشة يجب أن تعالج الحالات الثلاث:
BlocBuilder<XBloc, XState>(
  builder: (context, state) {
    // ✅ Loading → skeleton (ليس CircularProgressIndicator المجرد)
    if (state is XLoading) return const AppLoadingState();
    // ✅ Error → icon + message + retry
    if (state is XError) return AppErrorState(
      message: state.message,
      onRetry: () => context.read<XBloc>().add(LoadX()),
    );
    // ✅ Empty → illustration + message + action
    if (state is XEmpty) return AppEmptyState(
      title: l.noTripsYet,
      subtitle: l.startYourFirstTrip,
    );
    // ✅ Data
    if (state is XLoaded) return _buildContent(state);
    return const SizedBox.shrink();
  },
)

// ❌ NEVER:
if (isLoading) return CircularProgressIndicator()   // بلا skeleton
if (hasError) return Text('Error: $error', color: Colors.red) // بدائي
if (trips.isEmpty) return Text('No trips')          // بدون تصميم
```

### المتطلبات الإلزامية
```
□ AppBar أو Header واضح مع title
□ Loading state → AppLoadingState (shimmer)
□ Error state → AppErrorState (icon + msg + retry)
□ Empty state → AppEmptyState (illustration + msg + action)
□ RefreshIndicator على المحتوى القابل للتمرير
□ SafeArea للنوتش وشريط التنقل السفلي
□ Dark mode يعمل (كل الألوان ديناميكية)
□ RTL العربية يعمل بشكل صحيح
□ Touch targets ≥ 44×44px
```

---

## §6b Loading داخل الأزرار (Inline Loaders)

```dart
// ✅ CORRECT — CircularProgressIndicator مقبول داخل button فقط
ElevatedButton(
  onPressed: _isLoading ? null : _submit,
  child: _isLoading
      ? const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.white,
          ),
        )
      : Text(l.submit, style: context.ts.labelMd),
)

// ✅ CORRECT — AppButton لديه loading state جاهز
AppButton(
  label: l.submit,
  isLoading: _isLoading,
  onPressed: _submit,
)

// ❌ WRONG — أدار الشاشة كلها لعملية فورية
// حينما loading يخص action محدد (submit/upload)،
// استخدم inline loader فيالزر، ليس CircularProgressIndicator للشاشة
if (isLoading) return const Center(child: CircularProgressIndicator()); // ❌
```

### قاعدة Loading الحديدية
```
للشاشة كلها (initial load)    → AppLoadingState (shimmer)
لعملية فورية (submit/upload)    → inline SizedBox + CircularProgressIndicator
للأزرار (AppButton)           → isLoading: true داخل AppButton
```

---

## §7 شارات الحالة (Status Badges)

```dart
// قالب Badge القياسي
Container(
  padding: AppSpacing.chip,
  decoration: BoxDecoration(
    color: statusColor.withValues(alpha: 0.12),
    borderRadius: AppRadius.full_,
  ),
  child: Text(
    statusText,
    style: context.ts.labelXs.colored(statusColor),
  ),
)

// ألوان حالات الرحلة
TripStatus.searching      → AppColors.warning    + Icons.schedule
TripStatus.accepted       → AppColors.primary    + Icons.directions_car
TripStatus.driverArriving → AppColors.info       + Icons.near_me
TripStatus.inProgress     → AppColors.secondary  + Icons.navigation
TripStatus.completed      → AppColors.success    + Icons.check_circle
TripStatus.cancelled      → AppColors.error      + Icons.cancel

// ✅ استخدم AppTripStatusChip الجاهز بدل بناء واحد من الصفر
AppTripStatusChip(status: trip.status)
```

---

## §8 الأنيميشن والتفاعلية

### مدد الأنيميشن
```dart
const kFastAnimation   = Duration(milliseconds: 150);  // hover, press
const kNormalAnimation = Duration(milliseconds: 300);  // state change
const kSlowAnimation   = Duration(milliseconds: 500);  // page enter
```

### القواعد
- ✅ **قوائم**: SharedAnimatedTripCard للـ staggered fade+slide
- ✅ **State changes**: AnimatedSwitcher بـ 300ms crossfade
- ✅ **Bottom sheets**: Slide up + Curves.easeOutCubic
- ✅ **Buttons press**: Scale 0.97 + spring back
- ❌ NEVER instant state changes — دائماً animate
- ❌ NEVER LinearInterpolation — استخدم Curves.easeOutCubic

### Scale on Press
```dart
GestureDetector(
  onTapDown: (_) => setState(() => _pressed = true),
  onTapUp: (_) => setState(() => _pressed = false),
  onTapCancel: () => setState(() => _pressed = false),
  child: AnimatedScale(
    scale: _pressed ? 0.97 : 1.0,
    duration: kFastAnimation,
    child: yourWidget,
  ),
)
```

---

## §9 Responsive + RTL

```dart
// الحجم
final sw = MediaQuery.of(context).size.width;
// Bottom sheets: maxHeight
maxHeight: MediaQuery.of(context).size.height * 0.85
// Dialogs
width: math.min(400, sw - 48)

// RTL — تحقق دائماً
Directionality.of(context) == TextDirection.rtl
```

---

## §10 قائمة تحقق UI

```
□ كل الألوان من AppColors أو context extensions
□ كل المسافات من AppSpacing tokens (لا hardcoded numbers)
□ كل الزوايا من AppRadius (لا hardcoded BorderRadius.circular(x))
□ كل الطباعة من context.ts (لا hardcoded TextStyle)
□ Loading state → AppLoadingState (shimmer)
□ Error state → AppErrorState مع retry button
□ Empty state → AppEmptyState مع illustration
□ Dark mode يعمل (لا ألوان hardcoded)
□ RTL العربية يعمل
□ Touch targets ≥ 44×44px
□ SafeArea مفعّل
□ RefreshIndicator على القوائم
□ CircularProgressIndicator مسموح فقط داخل button (18px) أو فوق map icon
□ لا withOpacity() — استخدم withValues(alpha:) دائما
```
