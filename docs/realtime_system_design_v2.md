# تصميم نظام الـ Realtime — السيارات والهيت ماب

> **ملاحظة:** الـ CSV المرجعي للـ schema موجود في:
> `docs/Supabase Snippet AI-Powered PostgreSQL Schema X-Ray Introspection.csv`

---

## الفكرة ببساطة — قبل ما ندخل في أي تفاصيل

تخيل عندك صاحب اسمه "سيرفر"، وعندك مهمتين:

**المهمة الأولى (القديمة):**
> أنت: "في سيارات جنبي؟"
> سيرفر: "أيوه، ٣ سيارات"
> *(بعد ٥ ثواني)*
> أنت: "في سيارات جنبي؟"
> سيرفر: "أيوه، نفس الـ ٣" ← **مفيش جديد، بس رحت وجيت!**

**المهمة الثانية (الجديدة):**
> أنت: "يا صاحبي، لو حاجة اتغيرت، قولي"
> سيرفر: *صمت...* *صمت...* *صمت...*
> سيرفر: "جه سواق جديد!"
> أنت: "تمام، شكراً"
> ← **أنت مكنتش بتسأل خالص، السيرفر هو اللي كلمك!**

ده هو الفرق بين **Polling** (القديم) و **Realtime** (الجديد).

---

## السيناريو الكامل — سيارات السواقين عند المستخدم

### الصورة الكاملة في ٣ خطوات

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│   السواق "أحمد" بيتحرك في المعادي                              │
│         ↓                                                        │
│   تليفونه بيكتشف إنه اتحرك ٢٠ متر                              │
│         ↓                                                        │
│   التطبيق يبعت لـ Supabase: "أحمد دلوقتي في 29.96, 31.25"     │
│         ↓                                                        │
│   ┌─────────────────────────────────────┐                       │
│   │  drivers_profile (الجدول في الـ DB) │                       │
│   │  id="ahmed" | lat=29.96 | lng=31.25 │  ← اتحدّث!           │
│   │  geohash5="svy1q" | is_available=✅ │                       │
│   └─────────────────────────────────────┘                       │
│         ↓                                                        │
│   Supabase شاف التغيير وبعت لكل اللي مشتركين:                   │
│   "أحمد اتحرك لـ 29.96, 31.25"                                  │
│         ↓                                                        │
│   تطبيق مريم (المستخدمة) استقبل الـ event                       │
│   driversMap["ahmed"] = {lat: 29.96, lng: 31.25}                │
│         ↓                                                        │
│   ماركر أحمد اتحرك على الماب بتاع مريم فوراً ✅                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### لما مريم تتحرك لمنطقة تانية

الكود القديم كان بيعمل كده:
```
مريم اتحركت → امسح كل السيارات → اجيب من أول
← السيارات بتختفي لحظة قبل ما الجديدة توصل ❌
```

الكود الجديد بيعمل كده:
```
مريم اتحركت للمنطقة الجديدة

الخلايا القديمة: [svy1q, svy1r, svy1p]
الخلايا الجديدة: [svy2r, svy2q, svy2p]

اشترك في الجديدة فقط  ✅
فك اشتراك القديمة فقط ✅
السيارات الموجودة في driversMap فاضلة موجودة ✅
← صفر اختفاء، صفر flash ✅
```

---

## السيناريو الكامل — الهيت ماب عند السائق

### مريم بتفتح التطبيق في الزمالك

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  مريم فاتحت التطبيق                                            │
│        ↓                                                         │
│  LocationService كشف موقعها: lat=30.06, lng=31.22               │
│        ↓                                                         │
│  UserPresenceService:                                            │
│  "لما مريم تتحرك أكتر من ٢٠ متر، ابعت للداتابيز"               │
│        ↓  (لما اتحركت)                                           │
│  ┌─────────────────────────────────────┐                        │
│  │  user_presence (الجدول في الـ DB)   │                        │
│  │  user_id="maryam" | lat=30.06       │  ← اتكتب!             │
│  │  lng=31.22 | last_seen=now()        │                        │
│  └─────────────────────────────────────┘                        │
│        ↓                                                         │
│  Supabase شاف التغيير وبعت لكل السواقين المشتركين:              │
│  "مريم ظهرت/اتحركت في 30.06, 31.22"                             │
│        ↓                                                         │
│  تطبيق أحمد (السائق) استقبل الـ event                           │
│  presenceMap["maryam"] = {lat: 30.06, lng: 31.22}               │
│        ↓                                                         │
│  الهيت ماب اتحدّث → منطقة الزمالك بقت أكثر كثافة ✅             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### لما مريم تبدأ رحلة

```
مريم ضغطت "تأكيد الرحلة"
      ↓
TrackingBloc:
  DELETE من user_presence WHERE user_id = "maryam"
      ↓
Supabase بعت لأحمد:
  { event: "DELETE", user_id: "maryam" }
      ↓
presenceMap.remove("maryam")
الهيت ماب اتحدّث → مريم اختفت من المنطقة ✅

لما الرحلة تخلص:
  upsert user_presence تاني → مريم ترجع للهيت ماب ✅
```

---

## قواعد الظهور والاختفاء

```
╔══════════════════════════════════════════════════════════════╗
║  السيارات عند المستخدم تظهر لما:                            ║
║    ✅ السواق is_available = true                             ║
║    ✅ السواق في خلية جنب المستخدم (geohash5)                ║
║                                                              ║
║  السيارات بتختفي بس لو:                                     ║
║    ❌ Supabase بعت event إن السواق بقى غير متاح             ║
║    ❌ السواق خرج من نطاق الخلايا بتاعة المستخدم             ║
║    ❌ السواق خرج من التطبيق → set_driver_offline            ║
║                                                              ║
║  الهيت ماب عند السائق يظهر لما:                             ║
║    ✅ مستخدم اتحرك → INSERT/UPDATE في user_presence         ║
║                                                              ║
║  الهيت ماب بيختفي بس لو:                                    ║
║    ❌ Supabase بعت event DELETE لمستخدم (بدأ رحلة)          ║
║    ❌ المستخدم عمل Logout أو التطبيق حذف الـ presence صراحة ║
║    ❌ المستخدم خرج من التطبيق → DELETE من user_presence     ║
║                                                              ║
║  في كل الأحوال التانية:                                     ║
║    ✅ Navigation بين الشاشات → لا يحصل أي تغيير             ║
║    ✅ Bloc dispose → لا يحصل أي تغيير                       ║
║    ✅ السواق أو المستخدم واقف مش بيتحرك → يفضل ظاهر        ║
╚══════════════════════════════════════════════════════════════╝
```

---

## التغييرات المطلوبة في الداتابيز

> جميع التغييرات دي بتتنفذ من **Supabase SQL Editor**

---

### 1. تفعيل Realtime على `driver_public_profile` (View)

```
الوضع الحالي:
  drivers_profile      → Realtime ✅ (مفعّل)
  driver_public_profile → Realtime ❌ (View، مش محتاج)
  
القرار: هنشترك على drivers_profile مباشرة
مش محتاج تغيير هنا ✅
```

---

### 2. عدم إضافة Index على `last_seen`

الوضع الحالي: `user_presence` عندها index على `user_id` بس، وده كافي للتحديث/الحذف بالـ PK.
مش هنضيف index على `last_seen` لأننا مش هنعتمد على cleanup بزمن، وكمان الـ CSV موضح إن index ده اتشال عشان HOT updates تفضل أسرع.

```sql
DROP INDEX IF EXISTS public.idx_user_presence_last_seen;
```

---

### 3. تعطيل `cleanup_stale_user_presence`

الوضع الحالي في الـ CSV:
```sql
-- الكود الحالي (من الـ CSV):
DELETE FROM user_presence 
WHERE last_seen < NOW() - INTERVAL '5 minutes';
```

المشكلة:
- في الكود الجديد، UserPresenceService بيبعت update بس لما المستخدم يتحرك
- لو المستخدم واقف مش بيتحرك → مفيش update → أي cleanup بزمن هيخفيه بالغلط

الحل: نخلي function موجودة للتوافق، لكنها لا تحذف أي rows:

```sql
-- تعديل الـ function (تنفّذ في Supabase SQL Editor):
CREATE OR REPLACE FUNCTION public.cleanup_stale_user_presence()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN 0;
END;
$$;
```

---

### 4. إلغاء أي pg_cron Job للـ Cleanup

الوضع الحالي: **مفيش cron job** (تأكدنا من الـ CSV — `CRON sections: Empty`).
ده مناسب للتصميم الجديد: مفيش حذف بزمن. ولو job قديم اتضاف من محاولة سابقة، لازم يتشال.

```sql
DO $$
DECLARE
  v_jobid bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    FOR v_jobid IN
      SELECT jobid
      FROM cron.job
      WHERE jobname = 'cleanup-stale-user-presence'
         OR command ILIKE '%cleanup_stale_user_presence%'
    LOOP
      PERFORM cron.unschedule(v_jobid);
    END LOOP;
  END IF;
END $$;
```

---

### 5. إضافة RLS Policy على `drivers_profile` للـ Realtime

الوضع الحالي من الـ CSV:
```
drivers_profile_select: (id = auth.uid()) OR (is_verified = true)
```

ده معناه: أي مستخدم authenticated يقدر يشوف السواقين الـ verified.
الـ Realtime subscription هيشتغل عادي مع الـ policy دي ✅

لكن محتاجين نتأكد إن الـ Realtime مش بيبعت بيانات حساسة:

```sql
-- إنشاء view للـ Realtime بدل ما نكشف كل الـ drivers_profile
-- ده اختياري لكن أفضل للـ security
CREATE OR REPLACE VIEW public.driver_realtime_view AS
SELECT
  id,
  current_lat,
  current_lng,
  geohash5,
  is_available,
  heading,
  vehicle_type
FROM public.drivers_profile
WHERE is_verified = true
  AND is_available = true;

-- ملاحظة: Views مش بتدعم Realtime في Supabase
-- يعني هنشترك على drivers_profile الأصلي
-- وهنفلتر is_available و is_verified في الكود ✅
```

---

### 6. إضافة Composite Index لتسريع الـ Realtime Events

الوضع الحالي من الـ CSV:
```
idx_drivers_profile_geohash5:
  CREATE INDEX ON drivers_profile USING btree (geohash5)
  WHERE (is_available = true)
```

ده كافي للـ query العادية ✅
لكن الـ Realtime بيبعت كل تغيير في الجدول — مش محتاج index إضافي.

---

### ملخص التغييرات المطلوبة في الداتابيز

```
┌─────────────────────────────────────────────────────────────────┐
│  التغيير                    │  الأولوية  │  الـ SQL             │
├─────────────────────────────────────────────────────────────────┤
│  تعطيل cleanup الزمني       │  🔴 لازم   │  راجع قسم 3          │
│  وإرجاع 0 فقط               │             │                      │
├─────────────────────────────────────────────────────────────────┤
│  إلغاء pg_cron cleanup      │  🔴 لازم   │  راجع قسم 4          │
│  لو موجود من محاولة سابقة  │             │                      │
├─────────────────────────────────────────────────────────────────┤
│  حذف index last_seen        │  🟡 مستحسن │  راجع قسم 2          │
│  للحفاظ على HOT updates     │             │                      │
├─────────────────────────────────────────────────────────────────┤
│  drivers_profile Realtime   │  ✅ جاهز    │  مش محتاج تغيير      │
├─────────────────────────────────────────────────────────────────┤
│  user_presence Realtime     │  ✅ جاهز    │  مش محتاج تغيير      │
└─────────────────────────────────────────────────────────────────┘
```

---

## الـ Architecture الجديدة — الصورة الكاملة

```
                    ┌──────────────────────────────┐
                    │       SUPABASE DATABASE       │
                    │                              │
                    │  drivers_profile             │
                    │  ┌──────────────────────┐   │
                    │  │ id | lat | lng       │   │
                    │  │ geohash5 | available │   │
                    │  └──────────────────────┘   │
                    │  Realtime ✅                  │
                    │                              │
                    │  user_presence               │
                    │  ┌──────────────────────┐   │
                    │  │ user_id | lat | lng  │   │
                    │  │ last_seen            │   │
                    │  └──────────────────────┘   │
                    │  Realtime ✅                  │
                    │                              │
                    └──────┬──────────────┬────────┘
                           │  WebSocket   │  WebSocket
                           │              │
               ┌───────────▼──┐      ┌────▼───────────┐
               │ تطبيق المستخدم│      │ تطبيق السائق   │
               │               │      │                │
               │ CellSub       │      │ HeatmapService │
               │ Service       │      │                │
               │ يشترك على     │      │ يشترك على      │
               │ drivers_      │      │ user_presence  │
               │ profile       │      │ (الكل)         │
               │ فلترة محلية:  │      │                │
               │ geohash5 داخل │      │ presenceMap    │
               │ خلاياي        │      │ {userId:pos}   │
               │               │      │                │
               │ driversMap    │      │ يرسم الهيت ماب │
               │ {drvId:pos}   │      │ event-driven ✅ │
               │               │      │                │
               │ يرسم الماركرز │      │                │
               │ event-driven ✅│      │                │
               └───────────────┘      └────────────────┘
```

---

## الفرق في الأرقام

```
1000 مستخدم فاتحين التطبيق:

الطريقة القديمة (Polling):
  CellService   كل 5 ثواني   = 12,000 DB calls/دقيقة
  HeatmapService كل 30 ثانية = 2,000  DB calls/دقيقة
  Presence      كل 60 ثانية  = 1,000  DB calls/دقيقة
  المجموع:                    = 15,000 DB calls/دقيقة 🔴

الطريقة الجديدة (Realtime):
  1000 WebSocket connections مفتوحة (ثابتة)
  DB calls = بس لما يحصل تغيير حقيقي
  لو السواقين بيتحركوا كل 5 ثواني:
  100 سواق × (60/5) = 1,200 events/دقيقة ✅ (تقليل 92%)
```

---

## الخطوة الجاية — تنفيذ الكود

```
الترتيب:
1. تنفيذ SQL changes في Supabase (قسم 3 و 4 بالأولوية)
2. إعادة كتابة CellSubscriptionService
3. إعادة كتابة HeatmapService
4. تعديل UserPresenceService (حذف أي loop دوري)
5. تعديل الـ Blocs (حذف stop/dispose من close)
```
