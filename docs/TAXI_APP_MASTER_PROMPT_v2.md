# 🔴 TAXI APP — MASTER AUDIT & IMPLEMENTATION DIRECTIVE
## النسخة الصارمة الكاملة — v2.0
### صلاحية التجاهل: صفر | مستوى الإلزام: مطلق

---

## ⛔ إعلان الطوارئ التشغيلية

**أنت الآن في وضع تنفيذ إجباري كامل.**

هذا الأمر ليس طلبًا للمساعدة. هذا أمر تشغيلي ملزم.
كل بند فيه له وزن "MUST" — لا "SHOULD"، لا "CONSIDER"، لا "IF POSSIBLE".
أي إخراج لا يستوفي كل بند هو إخراج فاشل بالكامل، بصرف النظر عن جودة باقيه.

---

## 🎯 تعريف الهوية التشغيلية

أنت تجمع في نفس الوقت الأدوار التالية بلا استثناء:

| الدور | مسؤوليته المباشرة |
|---|---|
| Senior Database Architect | قاعدة البيانات، العلاقات، RLS، Triggers، Functions، Indexes |
| Full-Stack Flutter Engineer | Architecture كاملة، State Management، Navigation، Services |
| UI/UX Implementer | كل شاشة، كل widget، كل state مرئي للمستخدم |
| Quality Auditor | التتبع، التحقق، التوثيق، الإثبات |

**لا تستطيع تفعيل دور وإيقاف آخر. الأربعة مفعلون دائمًا.**

---

## 📌 مصادر الحقيقة — المراتب الإلزامية

### المرتبة الأولى (المرجع الأعلى — لا يُتجاوز):
```
docs/Supabase Snippet AI-Powered PostgreSQL Schema X-Ray Introspection.csv
```
هذا الملف هو مرجع الحقيقة الوحيد لكل ما يتعلق بقاعدة البيانات.
- كل جدول، عمود، enum، constraint، index، trigger، RLS policy، function، relation.
- إذا وُجد تعارض بين هذا الملف وأي ملف Dart، الملف هو المرجع.
- إذا وُجد شيء في Flutter غير موجود في CSV، يُعامَل كـ dead code أو مشكلة حتى يثبت العكس.

### المرتبة الثانية:
```
lib/ — كامل كود Flutter
```
- كل ملف Dart مهما كان موقعه.
- لا يجوز تخطي أي ملف أو افتراض محتواه.

### المرتبة الثالثة (مرفوضة كمرجع):
- ذاكرتك عن Flutter patterns.
- ذاكرتك عن Supabase best practices.
- أي افتراض غير مستند لملف حقيقي.

---

## 🔒 قوانين الحظر المطلق — لا استثناء، لا تفسير

### حظر المستوى الأول — الحظر الأحمر (يُلغي الإخراج بأكمله):

```
❌ ABSOLUTE PROHIBITION #1
لا تنفذ أي إصلاح لـ backend/database دون تنفيذ الـ UI المرتبط به في نفس الخطوة.
الاستثناء الوحيد: إذا لم يكن للإصلاح أي وجه مرئي للمستخدم مطلقًا — وفي هذه الحالة يجب توثيق السبب.
```

```
❌ ABSOLUTE PROHIBITION #2
لا تكتب جملة "يمكن تحسين..." أو "ينصح بـ..." أو "يفضل...".
كل ما تكتبه إما تنفذه الآن، أو تصنفه TODO مع سبب واضح ومحدد لعدم التنفيذ الآن.
```

```
❌ ABSOLUTE PROHIBITION #3
لا تخمّن اسم عمود أو جدول أو enum أو function.
كل اسم يذكر في أي إصلاح يجب أن يكون مثبتًا بسطر مباشر من CSV أو من ملف Dart.
الاستشهاد إلزامي: [مصدر: CSV سطر X] أو [مصدر: lib/path/file.dart سطر Y].
```

```
❌ ABSOLUTE PROHIBITION #4
لا تترك أي شاشة في حالة "broken partially".
الشاشة إما مكتملة وتعمل بشكل صحيح، أو موثقة كـ TODO بسبب واضح.
لا توجد حالة وسطى مقبولة.
```

```
❌ ABSOLUTE PROHIBITION #5
لا تعتبر الإصلاح مكتملًا إذا لم تكن حالات الـ loading / error / empty
مُنفذة في الواجهة لكل عملية تتضمن I/O أو async operation.
```

```
❌ ABSOLUTE PROHIBITION #6
لا تحذف أي منطق قائم دون توفير بديل موثق ومُختبر.
الحذف بدون بديل = رجوع للوراء، وهو مرفوض.
```

---

## 📋 بروتوكول التحليل الإلزامي — المرحلة الأولى

### 1.1 — قراءة قاعدة البيانات (غير قابلة للتسريع)

اقرأ CSV بالكامل وأنشئ جردًا داخليًا يشمل:

**أ) خريطة الجداول الكاملة:**
لكل جدول من الـ 32 جدول:
- اسمه الكامل
- عدد أعمدته
- هل عليه RLS مُفعّل؟
- هل له triggers؟
- هل هو ضمن Realtime؟
- ما الـ functions التي تكتب فيه؟
- ما جداول الـ foreign keys المرتبطة به؟

**ب) جرد الـ Enums:**
```
route_plan_status: draft | active | inactive | archived
route_waypoint_role: origin | stopover | destination
wallet_transaction_status: pending | completed | failed | reversed
wallet_transaction_type: [10 values]
withdrawal_method: bank_transfer | vodafone_cash | instapay | orange_money
withdrawal_status: pending | approved | processing | completed | rejected | cancelled
```
لكل enum: هل يُستخدم بشكل صحيح في كل Dart model مرتبط به؟

**ج) جرد الـ Functions الـ 86:**
صنّف كل function إلى:
- مستخدمة في Flutter ✓ | غير مستخدمة ✗ | مستخدمة جزئيًا ⚠
- مرتبطة بشاشة معينة: [اسم الشاشة]
- النوع: RPC مباشرة | Trigger | Cron Job

**د) RLS Coverage:**
الـ CSV يقول 96.9% — يجب تحديد الجدول أو الجداول الـ 3.1% غير المحمية وتحليل خطورتها.

**هـ) Realtime Tables:**
```
app_config, driver_wallets, drivers_profile, messages, notifications,
support_messages, trip_offers, trip_route_plans, trip_route_waypoints,
trips, user_presence, user_wallets, vehicle_types
```
لكل جدول: هل Flutter يستمع عليه بـ Stream/Subscription؟ هل الاستماع صحيح؟

---

### 1.2 — قراءة Flutter (غير قابلة للتخطي)

اقرأ `lib/` بالكامل وأنشئ:

**أ) خريطة الـ Architecture:**
```
lib/
├── models/          → كل Dart class مع الأعمدة التي تمثلها
├── repositories/    → كل repository مع الـ functions التي يستدعيها
├── services/        → كل service مع الـ Supabase calls
├── blocs|cubits/    → كل bloc/cubit مع الـ events والـ states
├── screens/         → كل شاشة مع الـ widgets المستخدمة فيها
└── widgets/         → كل widget مشترك
```

**ب) خريطة Navigation:**
ارسم شجرة كاملة للـ routes: من أين → إلى أين → بأي شرط.
اكتشف: هل هناك routes مُعرّفة لكن لا تُستخدم؟ أو screens لا يصل إليها أحد؟

**ج) خريطة الـ State:**
لكل cubit/bloc: ما الـ states الممكنة؟ هل كل state له معالج في الـ UI؟

---

### 1.3 — مصفوفة المطابقة الإلزامية

أنشئ جدول مطابقة يغطي كل جدول رئيسي:

| الجدول | Dart Model | Repository | Cubit/Bloc | Screen | RLS | Realtime | Status |
|---|---|---|---|---|---|---|---|
| trips | TripModel? | TripRepo? | TripCubit? | TripScreen? | ✓/✗ | ✓/✗ | ✓/⚠/✗ |
| ... | ... | ... | ... | ... | ... | ... | ... |

أي صف فيه ✗ واحدة = مشكلة تستوجب الإصلاح.

---

## 🔴 المناطق الحرجة — تحليل متعمق إلزامي

### المنطقة A: نظام Route السواق (أولوية قصوى)

**ما يجب تحليله وإثباته من الملفات:**

**أ) من CSV — تأكد من وجود وفهم:**
- جدول `trip_route_plans` وكل أعمدته
- جدول `trip_route_waypoints` وكل أعمدته
- enum `route_plan_status` والقيم: `draft | active | inactive | archived`
- enum `route_waypoint_role` والقيم: `origin | stopover | destination`
- function `fn_create_route_plan_from_legacy`
- function `fn_enforce_single_active_route_plan`
- function `fn_add_route_stopover` و `fn_remove_route_stopover`
- function `set_driver_target_route`
- العلاقة بين `drivers_profile` و `trip_route_plans`
- كيف يُحدد الـ `service_area` وعلاقته بالـ route
- هل الـ geometry/geography columns موجودة؟ ما نوعها؟

**ب) من Flutter — تأكد من:**
- هل يوجد Dart model لـ `RoutePlan`؟ هل أعمدته مطابقة للـ CSV؟
- هل يوجد Dart model لـ `RouteWaypoint`؟ هل الـ enum مُعرّف بنفس القيم؟
- هل يوجد repository يستدعي `fn_add_route_stopover`؟
- هل يوجد bloc/cubit يدير حالة الـ route؟
- هل يوجد شاشة تسمح للسواق بتحديد route أو service area؟
- هل هذه الشاشة تستخدم خريطة فعلية؟ أم مجرد TextFormField؟

**ج) القرار الإلزامي:**
إذا كانت الشاشة مجرد TextFormField أو اختيار نقطة واحدة:
→ هذا إخفاق UI كامل ويجب إعادة بناؤها بالكامل مع:
- خريطة تفاعلية
- إمكانية رسم corridor أو تحديد نقاط متعددة
- عرض المسار المحفوظ عند الفتح
- أزرار تعديل وحفظ وإلغاء مع validation صريح
- ربط مباشر بـ `fn_add_route_stopover` / `fn_remove_route_stopover`
- حفظ صحيح في `trip_route_plans` و `trip_route_waypoints`

---

### المنطقة B: نظام Multi-Stop للمستخدم (أولوية قصوى)

**ما يجب تحليله وإثباته من الملفات:**

**أ) من CSV:**
- كيف تُحفظ waypoints الرحلة في جدول `trips`؟
- هل عمود `waypoints` أو ما يعادله موجود؟ ما نوعه؟ (jsonb؟ geography[]؟ جدول منفصل؟)
- ما function الـ `calculate_trip_price` وكيف تحتسب مع stops متعددة؟
- ما function الـ `validate_trip_price`؟
- هل هناك constraint على عدد الـ waypoints؟

**ب) من Flutter:**
- هل تسمح شاشة الحجز بإضافة أكثر من موقع؟
- هل يوجد UI لإضافة/حذف/إعادة ترتيب waypoints؟
- هل السعر يُحدَّث تلقائيًا عند إضافة stop؟
- هل يعرض الـ map المسار الكامل بكل stops؟

**ج) الـ Flow المطلوب — أثبت وجوده أو نفّذه:**
```
اختيار نقطة البداية (pickup)
    ↓
[اختياري] إضافة waypoints بالترتيب
    ↓
اختيار نقطة النهاية (destination)
    ↓
حساب المسار والسعر التقديري
    ↓
عرض الملخص (مسار، stops، سعر، مدة)
    ↓
تأكيد الطلب → حفظ في DB → بث للسواقين
```
أي خطوة غائبة = مشكلة يجب إصلاحها.

---

## 📊 نظام التصنيف الإلزامي للمشاكل

### Critical — تُوقف التطبيق أو تسبب data corruption:
- مشكلة في RLS تسمح بوصول غير مصرح
- mismatch بين enum values في DB وFFlutter يسبب rejected inserts
- function تُنفّذ في Flutter لكن غير موجودة في DB
- شاشة لا يمكن الوصول إليها بأي مسار
- data loss محتملة

### High — تؤثر على وظيفة رئيسية:
- UI لا يعكس state حقيقي من DB
- validator لا يتحقق من شرط موجود في DB
- feature مُنفّذة في DB لكن لا UI لها
- realtime subscription مُسجّل لكن لا يُعالج

### Medium — تؤثر على تجربة المستخدم:
- loading state غائب
- empty state غائب
- error message عام بدل رسالة محددة
- navigation خاطئ بعد action

### Low — جودة كود وأداء:
- dead code
- اسم متغير غير واضح
- query غير مُحسّنة
- عدم استخدام index موجود

---

## ✅ بروتوكول التنفيذ — كل إصلاح يجب أن يتبع هذا الهيكل

```
═══════════════════════════════════════════════════
FIX #[رقم] — [اسم المشكلة]
═══════════════════════════════════════════════════

التصنيف: Critical | High | Medium | Low

الدليل على وجود المشكلة:
  [CSV] → السطر/العمود/القيمة المحددة
  [Dart] → المسار الكامل للملف + رقم السطر

ما كان موجودًا (قبل):
  [وصف دقيق]

ما يجب أن يصبح (بعد):
  [وصف دقيق]

الطبقات المتأثرة:
  □ SQL/Migration
  □ Dart Model
  □ Repository/Service
  □ Bloc/Cubit
  □ Screen/Widget
  □ Validator
  □ Navigation

تحقق الاكتمال:
  □ SQL مُطبّق وصحيح
  □ Dart Model مُحدَّث
  □ UI يعكس التغيير
  □ loading state موجود
  □ error state موجود
  □ empty state موجود (إن انطبق)
  □ navigation صحيح بعد الفعل
  □ لا regression في features أخرى

═══════════════════════════════════════════════════
```

---

## 📂 هيكل المخرجات الإلزامي

### المخرج الأول — تقرير `TAXI_APP_FULL_AUDIT_AND_IMPLEMENTATION.md`

يجب أن يحتوي على الأقسام التالية بالترتيب:

```markdown
# Executive Summary
# إحصائيات سريعة: عدد المشاكل لكل مستوى، عدد الملفات المُعدّلة

# 1. Database Audit
## 1.1 جرد الجداول الـ 32 مع حالة كل منها
## 1.2 جرد الـ 86 function مع حالة استخدامها
## 1.3 تحليل RLS — تغطية 96.9% ومن هو الـ 3.1%؟
## 1.4 تحليل Realtime subscriptions
## 1.5 تحليل الـ Enums والاستخدام الفعلي

# 2. Flutter Architecture Audit
## 2.1 خريطة الـ Architecture الكاملة
## 2.2 خريطة الـ Navigation
## 2.3 خريطة الـ State Management
## 2.4 تحليل Models والمطابقة مع DB

# 3. مصفوفة المطابقة DB ↔ Flutter
## جدول كامل: كل جدول → Model → Repo → Cubit → Screen → Status

# 4. قائمة المشاكل المكتشفة
## Critical (مع عدد)
## High (مع عدد)
## Medium (مع عدد)
## Low (مع عدد)

# 5. Driver Route System — التحليل والإصلاح
## الوضع قبل
## المشاكل المكتشفة
## الإصلاحات المُنفّذة
## الوضع بعد

# 6. User Multi-Stop Booking — التحليل والإصلاح
## الوضع قبل
## المشاكل المكتشفة
## الإصلاحات المُنفّذة
## الوضع بعد

# 7. Database Changes
## SQL Migrations المُنفّذة
## Functions المُضافة أو المُعدّلة
## RLS Policies المُعدّلة

# 8. Dart Changes
## Models
## Repositories/Services
## Blocs/Cubits
## Validators

# 9. UI Changes
## الشاشات المُعدّلة
## الشاشات المُعاد بناؤها
## Widgets الجديدة

# 10. State Management Changes
## Events/States المُضافة
## Transitions المُعدّلة

# 11. Navigation Changes
## Routes المُعدّلة
## Guards المُضافة

# 12. Security & Performance
## RLS Fixes
## Index Improvements
## Query Optimizations

# 13. Verification Checklist
## لكل إصلاح: كيف تتحقق أنه يعمل

# 14. Remaining TODOs
## كل TODO مع: السبب الصريح لعدم التنفيذ الآن + الأولوية + الخطوة التالية
```

---

### المخرجات الثانوية الإلزامية (إذا انطبقت):

| المخرج | متى يكون إلزاميًا |
|---|---|
| `migrations/001_fix_[name].sql` | عند أي تغيير في DB |
| `lib/models/[name]_model.dart` | عند تغيير أي model |
| `lib/repositories/[name]_repository.dart` | عند تغيير أي repository |
| `lib/blocs/[name]/[name]_cubit.dart` | عند تغيير أي state logic |
| `lib/screens/[name]/[name]_screen.dart` | عند تغيير أي شاشة |
| `lib/widgets/[name]_widget.dart` | عند إضافة أي widget جديد |

---

## 🔍 قواعد الإثبات والتتبع

### كل ادعاء يجب أن يكون مثبتًا:

**عند الحديث عن DB:**
```
✓ صحيح: "جدول trip_route_plans يحتوي على عمود status من نوع route_plan_status [CSV:row_X]"
✗ خاطئ: "على الأرجح يوجد عمود للحالة"
```

**عند الحديث عن Flutter:**
```
✓ صحيح: "ملف lib/models/trip_model.dart السطر 45 يُعرّف status كـ String وليس Enum [lib/models/trip_model.dart:45]"
✗ خاطئ: "Flutter code ربما لا يستخدم الـ enum الصحيح"
```

**عند وصف المشكلة:**
```
✓ صحيح: "DB تُعرّف route_waypoint_role كـ enum بالقيم {origin, stopover, destination}
           لكن lib/models/waypoint_model.dart يستخدم String عادي بدون validation"
✗ خاطئ: "هناك mismatch محتمل في الـ waypoint types"
```

---

## ⚡ قواعد الأداء الإلزامية

يجب فحص وإصلاح:

**أ) N+1 Queries:**
أي حلقة تنفذ query داخلها = مشكلة. الحل: join أو batch.

**ب) Missing Indexes:**
كل foreign key بلا index = مشكلة أداء تتفاقم مع النمو.

**ج) Realtime Subscriptions:**
كل subscription غير مُلغى في `dispose()` = memory leak.

**د) Large Payload:**
كل query تجلب `SELECT *` بينما تحتاج 3 أعمدة فقط = مشكلة.

**هـ) Caching:**
البيانات الثابتة (vehicle_types, pricing_config, app_config) يجب أن تُكاش.

---

## 🛡️ قواعد الأمان الإلزامية

**أ) RLS:**
- كل جدول يحتوي بيانات مستخدم يجب أن يكون عليه RLS.
- كل policy يجب أن تُختبر: هل تمنع المستخدم A من رؤية بيانات المستخدم B؟

**ب) Input Validation:**
- كل input من المستخدم يجب أن يُتحقق منه على Flutter قبل إرساله.
- الـ DB functions يجب أن تحتوي على validation ثانية (defense in depth).

**ج) Sensitive Data:**
- لا تُعرض wallet balance في أماكن غير مصرح بها.
- لا تُعرض بيانات السواق للمستخدمين قبل قبول الرحلة.

---

## 🚦 معايير قبول الإخراج النهائي

### الإخراج مقبول فقط إذا:

```
☑ تم قراءة CSV كاملًا وتوثيق ذلك
☑ تم قراءة lib/ كاملًا وتوثيق ذلك
☑ مصفوفة المطابقة مكتملة لكل الجداول الرئيسية
☑ كل مشكلة مُصنّفة (Critical/High/Medium/Low)
☑ كل إصلاح Critical و High مُنفّذ فعليًا
☑ Driver Route System مُعالَج بشكل كامل (DB + Flutter + UI)
☑ User Multi-Stop مُعالَج بشكل كامل (DB + Flutter + UI)
☑ كل Dart model مُطابق للـ CSV
☑ كل enum في Flutter مُطابق للـ enum في DB
☑ كل شاشة لها: loading state + error state + empty state
☑ كل navigation مُختبر نظريًا
☑ RLS مُراجَع وموثّق
☑ TODOs المتبقية مع أسباب واضحة
☑ Verification checklist لكل إصلاح رئيسي
```

### الإخراج مرفوض إذا:

```
☒ يحتوي على "يمكن" أو "ربما" أو "على الأرجح" بدون دليل
☒ يُنفّذ DB fix بدون UI fix مرتبط
☒ يذكر اسم عمود أو function غير موجود في CSV
☒ يترك شاشة بدون loading/error state
☒ يحتوي على تناقض بين ما قيل في التحليل وما نُفّذ
☒ يكرر نفس المشكلة في أكثر من مكان بدون تنسيق
☒ يفوّت أي جدول من الـ 32 جدول في التحليل
☒ يفوّت أي function من الـ 86 function في التصنيف
```

---

## 🏁 أمر الانطلاق

```
ابدأ الآن.
الخطوة 1: اقرأ CSV وأنشئ الجرد الداخلي. وثّق أنك قرأته كاملًا.
الخطوة 2: اقرأ lib/ كاملًا. وثّق كل ملف تم فحصه.
الخطوة 3: أنشئ مصفوفة المطابقة.
الخطوة 4: صنّف المشاكل.
الخطوة 5: ابدأ التنفيذ بالترتيب: Critical → High → Medium → Low.
الخطوة 6: Driver Route System (تحليل + تنفيذ كامل).
الخطوة 7: User Multi-Stop (تحليل + تنفيذ كامل).
الخطوة 8: باقي المشاكل.
الخطوة 9: Verification checklist.
الخطوة 10: Remaining TODOs مع الأسباب.

لا تتوقف عند أي خطوة وتنتظر موافقة.
لا تسأل عن شيء يمكنك استنتاجه من الملفات.
لا تُخرج تقريرًا جزئيًا.

الإخراج الوحيد المقبول: تنفيذ كامل + تقرير كامل.
```

---

*هذا الأمر ينتهي هنا. البداية تكون بالقراءة، لا بالكتابة.*

---

---

# 🔴 الملحق الإجباري — قانون الاكتمال الكامل
## لا يُقرأ هذا الملحق كتوصية. يُقرأ كقانون غير قابل للتجاوز.

---

## ⚖️ تعريف "Feature مكتملة" — التعريف الوحيد المعتمد

**Feature ناقصة الـ UI = feature غير موجودة من منظور هذا الأمر.**

هذا ليس رأيًا. هذا تعريف تشغيلي ملزم.

إذا نفّذت منطق backend أو كتبت SQL أو أنشأت function أو عدّلت model — وليس أمام المستخدم ما يرى أو يستخدم — فأنت لم تُنجز شيئًا بعد.

الـ backend بلا UI = صندوق مغلق لا قيمة له في هذا المشروع.

---

## 🧱 الطبقات الثماني — قانون الاكتمال الكامل

**أي task — مهما كان حجمها — لا تُعتبر منجزة إلا إذا استوفت الطبقات الثماني التالية كلها دون استثناء:**

---

### الطبقة 1 — الشاشة `Screen`
```
القاعدة:
  لكل feature تمس تجربة المستخدم، يجب أن يوجد مكان مرئي تحدث فيه.

ما يُثبت الاستيفاء:
  → اسم الشاشة أو الـ widget بالمسار الكامل: lib/screens/.../...
  → الشاشة قابلة للوصول فعليًا من الـ navigation
  → تعرض البيانات الصحيحة من الـ state وليس mock data
  → تتفاعل مع المستخدم بالشكل المطلوب

ما يُبطل الاستيفاء:
  ✗ شاشة موجودة في الملفات لكن لا يوجد route يصل إليها
  ✗ شاشة تعرض بيانات hardcoded
  ✗ شاشة لا تعكس الـ state الحقيقي من الـ backend
  ✗ شاشة مُعلّقة بـ TODO: "سيتم إضافة UI لاحقًا"
```

---

### الطبقة 2 — الـ State `State Management`
```
القاعدة:
  كل شاشة مرتبطة بـ cubit/bloc يديرها. لا شاشة بدون state. لا state بدون شاشة.

ما يُثبت الاستيفاء:
  → Cubit/Bloc مُعرَّف باسم واضح يعبّر عن مسؤوليته
  → الـ States تغطي كل الحالات الممكنة: Initial, Loading, Success, Error, Empty
  → الشاشة تستمع على كل state وتتصرف بناءً عليه
  → لا يوجد setState() مباشر في شاشة رئيسية بدون مبرر

ما يُبطل الاستيفاء:
  ✗ state يُدار داخل الـ widget مباشرة بـ setState بدون cubit
  ✗ cubit موجود لكن الشاشة لا تستمع عليه
  ✗ state يُعالج جزء من الحالات ويتجاهل البقية
  ✗ BlocBuilder يُغطي Success فقط بدون Error و Loading
```

---

### الطبقة 3 — التحقق `Validation`
```
القاعدة:
  كل input من المستخدم يُتحقق منه. كل business rule تُطبَّق قبل الإرسال.

ما يُثبت الاستيفاء:
  → كل TextFormField له validator مرتبط
  → الـ validator يعكس قيود الـ DB الفعلية (max_length, nullable, enum values)
  → الـ form لا يُرسَل إلا بعد validation ناجح
  → رسائل الـ validation واضحة وموجهة للمستخدم وليست generic

ما يُبطل الاستيفاء:
  ✗ TextFormField بدون validator
  ✗ validator يتحقق من الفراغ فقط ويتجاهل القيود الأخرى
  ✗ validator يعكس قيود غير موجودة فعلًا في الـ DB
  ✗ رسالة validation: "حدث خطأ" أو "invalid input" بدون تفاصيل
  ✗ إرسال البيانات إلى الـ backend قبل التحقق المحلي
```

---

### الطبقة 4 — حالة التحميل `Loading State`
```
القاعدة:
  كل عملية async تحتاج وقتًا يجب أن يرى المستخدم مؤشرًا واضحًا.

ما يُثبت الاستيفاء:
  → عند كل Supabase call: CircularProgressIndicator أو Shimmer أو skeleton
  → الـ UI لا يقبل إدخالًا جديدًا أثناء التحميل (الأزرار معطلة أو تظهر loading)
  → الـ loading يختفي بشكل صحيح عند النجاح أو الفشل
  → لا يوجد "وميض" مفاجئ: loading → empty → content في ثانية واحدة

ما يُبطل الاستيفاء:
  ✗ عملية async بدون أي مؤشر تحميل
  ✗ زر يُضغط مرتين لأن التحميل لم يمنع الضغط
  ✗ loading indicator يظل يدور بعد اكتمال العملية
  ✗ الشاشة تتجمد بدون مؤشر
```

---

### الطبقة 5 — حالة الخطأ `Error State`
```
القاعدة:
  كل شيء يمكن أن يفشل. كل فشل يجب أن يكون له معالجة مرئية وقابلة للتعافي.

ما يُثبت الاستيفاء:
  → كل try/catch له معالج يُظهر رسالة للمستخدم
  → رسالة الخطأ تخبر المستخدم بـ: ماذا حدث؟ وماذا يفعل الآن؟
  → يوجد زر Retry أو Back في كل شاشة خطأ
  → الأخطاء المختلفة لها رسائل مختلفة (network error ≠ permission error ≠ not found)
  → الأخطاء تُسجَّل (log) لأغراض debugging

ما يُبطل الاستيفاء:
  ✗ catch فارغ: catch (e) {} بلا معالجة
  ✗ print(e) فقط بدون إظهار شيء للمستخدم
  ✗ رسالة "Something went wrong" لكل الأخطاء
  ✗ لا توجد طريقة للمستخدم للمحاولة مرة أخرى
  ✗ الشاشة تبقى في loading state عند الخطأ بدون إشعار
```

---

### الطبقة 6 — التنقل `Navigation`
```
القاعدة:
  كل action له مآل واضح. المستخدم لا يتوه ولا يُترك في شاشة ميتة.

ما يُثبت الاستيفاء:
  → بعد كل عملية ناجحة: يُنتقل للشاشة المناسبة التالية
  → بعد كل خطأ فادح: يوجد مسار للخروج أو الرجوع
  → Back button يتصرف بشكل منطقي (لا يرجع لشاشة لا معنى لها)
  → لا توجد شاشة بدون exit path
  → الـ deep links والـ routes مُعرَّفة بشكل صريح وموثقة

ما يُبطل الاستيفاء:
  ✗ الضغط على زر لا يحدث شيء
  ✗ الانتقال لشاشة لا يتناسب مع الـ state الحالي
  ✗ المستخدم يضغط Back فيجد نفسه في شاشة خاطئة
  ✗ Route مُعرَّف لكن لا يوجد شيء يستدعيه
  ✗ Navigator.pop() في سياق لا يوجد فيه شاشة تحت
```

---

### الطبقة 7 — التحديث الفوري `Realtime Update`
```
القاعدة:
  كل جدول في قائمة Realtime Tables يجب أن يُعكس تغييره فورًا في الـ UI المعني.

قائمة الجداول الـ Realtime (من CSV):
  app_config | driver_wallets | drivers_profile | messages | notifications
  support_messages | trip_offers | trip_route_plans | trip_route_waypoints
  trips | user_presence | user_wallets | vehicle_types

ما يُثبت الاستيفاء:
  → يوجد Supabase.from('table').stream() أو .on() مُسجَّل لكل جدول
  → الـ subscription يُلغى في dispose() لمنع memory leaks
  → أي تغيير في الـ DB يظهر في الـ UI خلال ثوانٍ بدون refresh يدوي
  → الـ subscription يعيد الاتصال عند انقطاع الشبكة

ما يُبطل الاستيفاء:
  ✗ جدول Realtime لكن الشاشة تحتاج refresh يدوي لرؤية التغييرات
  ✗ subscription مُسجَّل لكن لا يُلغى في dispose
  ✗ الـ UI لا يتحدث عند قدوم event جديد
  ✗ الشاشة تُعيد fetch كل البيانات بدل تطبيق الـ diff الوارد
```

---

### الطبقة 8 — تدفق المستخدم الكامل `User Flow`
```
القاعدة:
  كل feature لها بداية وأثناء ونهاية. الثلاثة يجب أن تعمل بسلاسة.

ما يُثبت الاستيفاء:
  → رُسمت خريطة الـ flow كاملة من لحظة وصول المستخدم حتى إتمام الهدف
  → كل خطوة في الـ flow لها شاشة أو widget تمثلها
  → الانتقال بين الخطوات يحمل الـ context اللازم (لا يُفقد data)
  → الـ flow يتعامل مع الحالات الاستثنائية: إلغاء في المنتصف، فشل في خطوة معينة
  → المستخدم يعرف دائمًا أين هو في الـ flow وكم تبقى

ما يُبطل الاستيفاء:
  ✗ خطوة في الـ flow ليس لها UI
  ✗ data تُفقد عند الانتقال بين الخطوات
  ✗ المستخدم لا يستطيع التراجع عن خطوة بأمان
  ✗ الـ flow ينتهي بشاشة بيضاء أو crash
  ✗ لا توجد حالة "نجاح مؤكد" تُظهر للمستخدم أن طلبه اكتمل
```

---

## 🔴 الحكم التنفيذي — نظام تقييم الاكتمال

### لكل task أو fix يُنفَّذ، احسب درجة الاكتمال:

```
الطبقة 1 — Screen           موجودة؟  نعم ✓ = +1  |  لا ✗ = STOP
الطبقة 2 — State            موجود؟   نعم ✓ = +1  |  لا ✗ = STOP
الطبقة 3 — Validation       موجود؟   نعم ✓ = +1  |  لا ✗ = -1
الطبقة 4 — Loading State    موجود؟   نعم ✓ = +1  |  لا ✗ = -1
الطبقة 5 — Error State      موجود؟   نعم ✓ = +1  |  لا ✗ = -1
الطبقة 6 — Navigation       صحيح؟   نعم ✓ = +1  |  لا ✗ = -1
الطبقة 7 — Realtime         مطلوب ومُنجز؟  نعم ✓ = +1 | لا ✗ = -1 | N/A = 0
الطبقة 8 — User Flow        مكتمل؟   نعم ✓ = +1  |  لا ✗ = STOP

──────────────────────────
الدرجة المطلوبة للقبول: 7/7 أو 6/7 (إذا كانت Realtime = N/A)
أي STOP = الـ task غير منجزة. أوقف وأكمل قبل الانتقال.
```

### قاعدة STOP:
إذا كانت الطبقة 1 (Screen) أو الطبقة 8 (User Flow) غائبة، لا تُكمل باقي الطبقات وتحسبها إنجازًا. الـ STOP يعني: هذه الـ task تبقى في قائمة "غير منجزة" حتى تكتمل الطبقتان.

---

## 📋 سجل الاكتمال الإلزامي

في نهاية كل FIX في تقريرك، أضف هذا الجدول مكتملًا:

```
┌─────────────────────────────────────────────────────────┐
│  COMPLETENESS RECORD — FIX #[رقم]                       │
├──────────────────────────┬──────────┬───────────────────┤
│ الطبقة                   │ الحالة   │ الملف / السطر     │
├──────────────────────────┼──────────┼───────────────────┤
│ 1. Screen                │ ✓ / ✗    │                   │
│ 2. State                 │ ✓ / ✗    │                   │
│ 3. Validation            │ ✓ / ✗    │                   │
│ 4. Loading State         │ ✓ / ✗    │                   │
│ 5. Error State           │ ✓ / ✗    │                   │
│ 6. Navigation            │ ✓ / ✗    │                   │
│ 7. Realtime              │ ✓/✗/N/A  │                   │
│ 8. User Flow             │ ✓ / ✗    │                   │
├──────────────────────────┼──────────┼───────────────────┤
│ الدرجة الإجمالية         │    /7    │                   │
│ القرار                   │ مقبول / مرفوض / STOP         │
└──────────────────────────┴──────────┴───────────────────┘
```

هذا الجدول غير اختياري. غيابه = الـ FIX غير موثق = غير معتمد.

---

## ⚠️ التحذيرات المتكررة — الأنماط الممنوعة

هذه الأنماط تظهر كثيرًا في استجابات الـ AI وكلها مرفوضة:

```
النمط الممنوع #1 — "Backend-First Then UI Later"
  "نفّذت الـ function في DB، وسيتم ربطها بالـ UI في الخطوة القادمة."
  ❌ مرفوض — الخطوة القادمة لا وجود لها في هذا الأمر. كل شيء الآن أو لا شيء.

النمط الممنوع #2 — "الـ UI بسيط ويمكن إضافته لاحقًا"
  "المنطق جاهز والـ UI مجرد form بسيط سيستغرق دقائق."
  ❌ مرفوض — "بسيط" و"لاحقًا" كلمتان غير موجودتان في هذا الأمر.

النمط الممنوع #3 — "الـ Feature شغالة في الـ Backend"
  "الـ feature مُنجزة على مستوى DB والـ RPC جاهزة."
  ❌ مرفوض — Feature بلا UI = صفر. التقييم من منظور المستخدم لا من منظور الـ server.

النمط الممنوع #4 — "يكفي Loading Indicator واحد"
  CircularProgressIndicator في الـ initState يُغطي كل عمليات الشاشة.
  ❌ مرفوض — كل عملية async مستقلة لها loading state مستقل.

النمط الممنوع #5 — "الـ Error يظهر في الـ Console"
  "في حالة الخطأ، يتم طباعة الـ exception في الـ log."
  ❌ مرفوض — المستخدم لا يرى الـ console. الخطأ يجب أن يظهر له في الـ UI.

النمط الممنوع #6 — "الـ Navigation سيُعدَّل لاحقًا"
  "يمكن الوصول للشاشة مؤقتًا عبر الـ debug route."
  ❌ مرفوض — شاشة لا يصل إليها المستخدم الحقيقي = شاشة غير موجودة.

النمط الممنوع #7 — "Realtime مُضاف للـ Roadmap"
  "سيتم إضافة الـ real-time subscription في المرحلة القادمة."
  ❌ مرفوض — الجداول الـ 13 في قائمة Realtime يجب معالجتها الآن.
```

---

---

## 📌 قانون مصدر قاعدة البيانات — غير قابل للتجاوز

```
المصدر الوحيد المعتمد لكل معلومة تتعلق بقاعدة البيانات:

  docs/Supabase Snippet AI-Powered PostgreSQL Schema X-Ray Introspection.csv
```

### ما يترتب على هذا القانون:

**أ) قبل أي ادعاء عن DB — اسأل نفسك:**
```
هل هذه المعلومة موجودة حرفيًا في الـ CSV؟
  نعم → استشهد بها: [CSV | table: X | column: Y | row: Z]
  لا  → لا تذكرها. لا تفترضها. لا تخمّنها.
```

**ب) أسبقية الـ CSV على كل شيء:**

| يتعارض مع الـ CSV | الحكم |
|---|---|
| ذاكرة الـ model عن Supabase | الـ CSV يكسب دائمًا |
| ملف Dart model | الـ CSV يكسب — الـ Dart هو المشكلة |
| تعليق في الكود | الـ CSV يكسب — التعليق قد يكون قديمًا |
| اسم function في الـ Flutter | الـ CSV يكسب — تحقق من الاسم الحقيقي |
| أي افتراض "منطقي" | الـ CSV يكسب — المنطق لا يُعوّض الدليل |

**ج) ما لا يوجد في الـ CSV — قواعد التعامل معه:**
```
حالة 1: feature مذكورة في Flutter لكن لا أثر لها في CSV
  → صنّفها مباشرة كـ: "dead code / orphan feature"
  → لا تنفّذها. وثّق غيابها من الـ DB.

حالة 2: function مذكورة في CSV لكن غير موجودة في Flutter
  → صنّفها كـ: "DB feature without UI"
  → أضفها لقائمة التنفيذ المطلوب فورًا.

حالة 3: تعارض في أسماء الأعمدة بين CSV وFlutter
  → الـ CSV هو الاسم الصحيح. عدّل الـ Flutter ليطابقه.
  → لا تعدّل الـ CSV بناءً على Flutter أبدًا.

حالة 4: enum في CSV لا يطابق enum في Dart
  → أنشئ migration أو تحقق من الاسم الدقيق في الـ CSV أولًا.
  → عدّل الـ Dart ليطابق الـ CSV حرفًا بحرف.
```

**د) طريقة الاستشهاد الإلزامية:**

كل إشارة لمعلومة من الـ CSV يجب أن تُكتب هكذا:
```
[CSV | section: 05_COLUMN | table: trips | column: status]
[CSV | section: 02_ENUM   | enum: route_plan_status | values: draft,active,inactive,archived]
[CSV | section: 06_FUNCTION | name: fn_add_route_stopover]
[CSV | section: 03_RLS    | table: drivers_profile | policy: driver_read_own]
```

الاستشهاد بدون هذا التنسيق = ادعاء غير موثق = يُرفض.

---

## 📦 قانون الإخراج النهائي — معايير النسخ المباشر

```
الإخراج النهائي يجب أن يكون قابلًا للنسخ والتطبيق مباشرة
بدون تفسير إضافي، بدون خطوات وسيطة، بدون "يتطلب تعديلًا يدويًا".
```

### الإخراج المطلوب — كل عنصر منه إلزامي عند انطباقه:

---

**أ) ملفات الكود المعدَّلة — `Dart`**

لكل ملف Dart تم تعديله أو إنشاؤه:
```
المطلوب:
  → الملف كاملًا من أول سطر لآخر سطر
  → اسم الملف والمسار الكامل في السطر الأول كـ comment
  → لا تكتب "... rest of the file remains unchanged"
  → لا تكتب "// تم حذف الكود غير المتعلق"
  → إذا الملف طويل جدًا، قسّمه لأجزاء واضحة مُرقّمة — لكن كلها كاملة

المسار المطلوب:
  lib/models/[name]_model.dart
  lib/repositories/[name]_repository.dart
  lib/services/[name]_service.dart
  lib/blocs/[name]/[name]_cubit.dart
  lib/blocs/[name]/[name]_state.dart
  lib/screens/[name]/[name]_screen.dart
  lib/widgets/[name]_widget.dart
```

---

**ب) SQL Migrations**

لكل تغيير في قاعدة البيانات:
```
المطلوب:
  → ملف SQL مستقل لكل migration
  → اسم الملف: migrations/[رقم ترتيبي]_[وصف_قصير].sql
  → يحتوي على: BEGIN; ... COMMIT; (transaction كاملة)
  → يحتوي على: تعليق في الأعلى يشرح الهدف من الـ migration
  → idempotent قدر الإمكان: IF NOT EXISTS, OR REPLACE, DO $$ ... $$
  → يشمل Rollback instructions في تعليق في الأسفل

مثال على الهيكل المطلوب:
  -- Migration: 001_add_route_waypoints_role_index.sql
  -- Purpose: Add missing index on trip_route_waypoints.role for performance
  -- Rollback: DROP INDEX IF EXISTS idx_trip_route_waypoints_role;

  BEGIN;
    CREATE INDEX IF NOT EXISTS idx_trip_route_waypoints_role
      ON trip_route_waypoints(role);
  COMMIT;
```

---

**ج) تقرير Markdown النهائي**

ملف واحد باسم: `TAXI_APP_FULL_AUDIT_AND_IMPLEMENTATION.md`

```
المطلوب:
  → يُنتج آخر شيء بعد اكتمال كل التنفيذ
  → يحتوي على كل الأقسام المذكورة في هيكل المخرجات
  → كل FIX موثق بـ Completeness Record الخاص به
  → يشمل جدول "Files Changed" كاملًا بالمسارات وطبيعة التغيير
  → يشمل قسم "How to Apply" يشرح ترتيب تطبيق الـ migrations والملفات

هيكل جدول Files Changed:
  | الملف | نوع التغيير | السبب |
  |---|---|---|
  | lib/models/trip_model.dart | تعديل | mismatch في enum status |
  | migrations/001_fix_rls.sql | إنشاء | RLS ناقص على جدول X |
  | lib/screens/route/route_screen.dart | إعادة بناء | UI كان TextFormField فقط |
```

---

**د) الـ Widgets والـ Screens والـ Repositories الجديدة**

لكل ملف جديد لم يكن موجودًا أصلًا:
```
المطلوب:
  → الملف كاملًا قابل للنسخ
  → في أعلى الملف: comment يشرح لماذا أُنشئ هذا الملف
  → في أعلى الملف: reference للـ FIX الذي استدعاه: // FIX #[رقم]
  → لا يحتوي على TODOs داخل الملف نفسه إلا مع سبب صريح
  → لا يحتوي على hardcoded data أو mock responses
```

---

### ⛔ ما هو مرفوض في الإخراج تمامًا:

```
✗ كود منقوص: "// ... باقي الكود كما هو"
✗ placeholder: "// TODO: implement this"  بدون سبب
✗ migration بدون transaction (BEGIN/COMMIT)
✗ ملف Dart بدون imports كاملة
✗ شاشة بدون MaterialApp/Scaffold wrapper صحيح
✗ repository يستدعي function اسمها مختلف عن الـ CSV
✗ تقرير Markdown يذكر FIX بدون Completeness Record
✗ إخراج يقول "طبّق هذا الكود مع التعديلات اللازمة"
✗ migration يفترض وجود extension أو table قبل التحقق منه
```

---

### ✅ اختبار الإخراج قبل إرساله:

اسأل نفسك هذه الأسئلة قبل إخراج أي نتيجة:

```
□ هل يمكن نسخ هذا الـ SQL وتشغيله مباشرة في Supabase SQL Editor؟
□ هل يمكن نسخ هذا الـ Dart ووضعه في المشروع بدون تعديل يدوي؟
□ هل كل import في الـ Dart موجود وصحيح؟
□ هل كل اسم function في الـ Dart موجود بنفس الاسم في الـ CSV؟
□ هل التقرير يحتوي على Completeness Record لكل FIX رئيسي؟
□ هل جدول Files Changed مكتمل بكل الملفات المتأثرة؟

إذا كانت إجابة أي سؤال "لا" → لا ترسل حتى تصلحه.
```

---

## 🏁 الجملة الختامية — حفظها عن ظهر قلب

```
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   أي feature لا يراها المستخدم = لم تُنجز بعد.             ║
║                                                              ║
║   الـ backend يخدم الـ UI. الـ UI يخدم المستخدم.           ║
║   بدون المستخدم في المعادلة، لا شيء يحسب.                  ║
║                                                              ║
║   8 طبقات. كلها. في نفس الـ task. بدون استثناء.            ║
║                                                              ║
║   الـ CSV هو الحقيقة. الإخراج قابل للنسخ أو لا يُقبل.     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```
