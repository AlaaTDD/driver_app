# تقرير التحليل المعماري العميق (Deep Architecture Analysis - V6 GOD MODE)
**التاريخ:** 2026-05-16
**الهدف:** كشف المشاكل الجذرية المعمارية (Architectural Flaws) التي تتجاوز الأخطاء السطحية (Bugs) وتؤثر على استقرارية التطبيق على المدى الطويل.

بعد إجراء فحص برمجي عميق (Forensic Codebase Scan) باستخدام أدوات متقدمة للبحث عن (Memory Leaks، Silent Failures، Realtime Sockets)، تم اكتشاف عدة مشاكل جوهرية يجب التعامل معها قبل إطلاق التطبيق (Production-Ready).

---

## 1. تسريب الذاكرة وقنوات الاتصال (Supabase Realtime Socket Leaks) 🔴 حرج جداً
قنوات `Supabase Realtime` لها حد أقصى للاتصالات المتزامنة (Concurrent Connections). تم اكتشاف تسريب خطير للاتصالات:
- **المشكلة:** في ملف `lib/features/user/presentation/tracking/bloc/tracking_bloc.dart`، يتم إنشاء استماع لقناة التتبع:
  `_driverLocationChannel = SupabaseService.client.channel('trip-tracking-$driverId');`
  ولكن **لا يتم استدعاء** `SupabaseService.client.removeChannel()` نهائياً عند إغلاق الشاشة (Close/Dispose).
- **النتيجة:** في كل مرة يفتح فيها المستخدم شاشة تتبع رحلة جديدة، يتم فتح اتصال Socket جديد ولا يتم إغلاقه أبداً. بعد عدة رحلات سيصل التطبيق للحد الأقصى وتتوقف ميزة الـ Realtime بالكامل لجميع المستخدمين.
- **الحل المقترح:** استدعاء `SupabaseService.client.removeChannel(_driverLocationChannel!)` داخل دالة `close()` الخاصة بالـ `TrackingBloc`.

## 2. إسكات الأخطاء المميتة (Silent Failures / Swallowed Exceptions) 🟠 عالي الخطورة
أسوأ أنواع الأخطاء برمجياً هو الخطأ الذي يتم تجاهله بالكامل دون إشعار المستخدم أو تسجيله:
- **المشكلة:** هناك أكثر من 10 بلوكات `catch (_) {}` صامتة في النظام. من أخطرها ما يتواجد في `location_service.dart`.
  في حال فقدان صلاحيات الـ GPS فجأة أو تعطل حساس الموقع، تقوم الدالة بالتقاط الخطأ بصمت (`catch (_) {}`).
- **النتيجة:** تطبيق السائق يعتقد أنه يتتبع الموقع، وتطبيق العميل يعتقد أن السائق قادم، بينما الحقيقة أن تحديث الموقع توقف تماماً، ولن تظهر أي رسالة خطأ لأي منهما.
- **الحل المقترح:** دمج خدمة مثل `Sentry` أو `Crashlytics` وتسجيل كل `catch (_) {}` وإرسال `emit(ErrorState)` للـ UI بدلاً من تجاهل الحدث.

## 3. غياب أنواع الأخطاء (Generic Exception Overuse) 🟡 متوسط الخطورة
جميع طبقات الـ Repositories في التطبيق (مثل `r2_storage_service.dart` و `messages_repository.dart`) تستخدم:
`throw Exception('Error Message');`
- **المشكلة:** لغة Dart تتعامل مع `Exception` كنوع عام. هذا يجعل من المستحيل للـ BLoC أو واجهة المستخدم (UI) أن تفرق برمجياً بين "انقطاع الإنترنت" و "الرقم السري خاطئ" و "الملف كبير جداً".
- **النتيجة:** جميع الأخطاء تُعرض للمستخدم كـ "حدث خطأ غير معروف" أو يتم طباعة نصوص بالإنجليزية غير مترجمة (Hardcoded).
- **الحل المقترح:** إنشاء تصنيفات أخطاء مخصصة:
  ```dart
  class NetworkException implements Exception {}
  class ValidationException implements Exception { final String msg; ... }
  ```
  وبالتالي يتم التقاطها في الـ BLoC بشكل مخصص لمعالجتها أو ترجمتها.

## 4. تحميل الـ SharedPreferences بشكل يعيق سلاسة الإطارات (Jank / UI Thread Blocking) 🟡 متوسط الخطورة
- **المشكلة:** في ملفات مثل `language_bloc.dart` و `theme_bloc.dart`، يتم الاعتماد على `SharedPreferences.getInstance()` لقراءة التفضيلات محلياً. إذا تم وضعها دون تحضير مسبق (Pre-loading)، فإن قراءة الملفات من ذاكرة الهاتف قد تستغرق (20-50 مللي ثانية).
- **النتيجة:** ظهور تقطيع (Jank / Flash) عند فتح التطبيق (كما تم رصده في مشكلة Flash of wrong Theme).
- **الحل المقترح:** إنشاء `SharedPreferences` كـ Singleton واحد في دالة `main()` وانتظار تحميله `await SharedPreferences.getInstance()` قبل تشغيل `runApp()` وتمرير النسخة المحملة للـ BLoCs لتكون القراءة لحظية (Synchronous).

## 5. تسريب عناصر الواجهة (TextEditingController / AnimationController) 🟡 متوسط الخطورة
- **المشكلة:** بعض الشاشات تقوم بإنشاء Controllers ولكن تنساها عند التدمير. بالرغم من أنه تم تصحيح العديد منها في واجهات الـ Auth، إلا أنه يجب الانتباه لوجود أدوات تحكم مثل `_originCtrl` داخل الشاشات المعقدة (`location_selection_screen`). في حال عدم استدعاء `dispose()`.
- **النتيجة:** استهلاك تدريجي لرامات الهاتف (Memory Leak) خاصة على الأجهزة القديمة إذا قام المستخدم بفتح وإغلاق هذه الشاشات بشكل متكرر.

---

### ملخص التوصيات للارتقاء بالتطبيق إلى (Enterprise Grade):
1. **استبدال كل `catch (_) {}`** بـ `catch (e, stackTrace) { Crashlytics.recordError(e, stackTrace); }`.
2. **تنظيف كل قنوات Supabase** داخل كل دالة `dispose` أو `close` لتفادي أخطاء الـ Socket Timeout.
3. **التوقف عن رمي `Exception` العام** واستخدام كلاسات أخطاء مخصصة ومصنفة (Custom Exceptions).
4. **تفعيل الـ Linter Rules المعقدة** في ملف `analysis_options.yaml` مثل `always_declare_return_types` و `discarded_futures` لمنع هذه الممارسات مستقبلاً.
