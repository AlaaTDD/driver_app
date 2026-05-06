# 📊 تحليل عميق لملفات المشروع (188 ملف) - `lib/`

تم إجراء تحليل دقيق وشامل لجميع ملفات `dart` الـ 188 الموجودة في مجلد `lib/` بالكامل، لاستخراج وتحديد جميع المشاكل المتعلقة بالترجمة (Localization) وتوافق الوضع الليلي (Dark Mode) وذلك **بدون استخدام أي أدوات أو سكربتات خارجية من بايثون** بناءً على طلبك.

---

## 🌍 1. مشاكل الترجمة واللغة (Localization & Translation Issues)

بعد الفحص الدقيق لجميع الودجات والنصوص الثابتة (Hardcoded Strings داخل `Text()`)، **النتيجة ممتازة جداً:** لقد قمت بعمل رائع مسبقاً في ربط المشروع بـ `AppLocalizations`. لم يتبقَ سوى **7 مواضع فقط** تحتوي على نصوص ثابتة، وأغلبها مجرد نصوص ملحقة بمتغيرات (مثل وحدات القياس أو العملات). 

**قائمة الملفات التي تحتاج إلى تعديل بسيط في الترجمة:**

1. **`lib/features/driver/presentation/trip_details/trip_details_screen.dart` (سطر 470)**
   - الكود الحالي: `Text('$label: ', ...)`
   - المشكلة: دمج النص بنقطتين بشكل مباشر.

2. **`lib/features/user/presentation/meeting_point/meeting_point_screen.dart` (سطر 432)**
   - الكود الحالي: `Text('${args?.price?.toStringAsFixed(2) ?? '0'} ${AppLocalizations.of(context)!.currencySar}')`
   - الملاحظة: شبه صحيح ولكن يفضل عدم دمج النصوص في سترينج واحد لتجنب مشاكل اتجاه الخط (RTL).

3. **`lib/features/user/presentation/tracking/tracking_screen.dart` (سطر 483)**
   - الكود الحالي: `Text('$label: ', style: ...)`

4. **`lib/features/user/presentation/trips/widgets/trip_card.dart` (سطر 79)**
   - الكود الحالي: `Text('$distance km', ...)`
   - المشكلة: كلمة **km** مكتوبة بشكل ثابت ويجب تغييرها إلى الترجمة `AppLocalizations.of(context)!.km`.

5. **`lib/features/user/presentation/trips/widgets/trip_card.dart` (سطر 81)**
   - الكود الحالي: `Text('$price SAR', ...)`
   - المشكلة: كلمة **SAR** ثابتة ويجب تغييرها إلى الترجمة `AppLocalizations.of(context)!.currencySar`.

6. **`lib/features/user/presentation/pricing/pricing_screen.dart` (سطر 556 و 650)**
   - الملاحظة: أرقام وعلامات سالب (-) مدموجة في نصوص، لا تُعد مشكلة ترجمة خطيرة، ولكن يفضل تمريرها كمتغيرات للـ Text.

✅ **الخلاصة:** نظام الترجمة شبه مكتمل ولا يحتاج سوى مسح أخير لهذه الـ 7 أسطر.

---

## 🌙 2. مشاكل الوضع الليلي (Dark Mode Issues)

هنا تكمن **المشكلة الأكبر** في الكود الحالي. لقد تم البحث عن استخدام الألوان الثابتة مثل `Colors.white` و `Colors.black` وألوان الـ Hex الصريحة مثل `Color(0xFF...)`، بالإضافة للاستخدام المباشر لـ `AppColors`.

**النتيجة:** تم العثور على **أكثر من 778 حالة** تستخدم ألواناً ثابتة، مما يمنع التطبيق من التبديل السلس بين الوضع المضيء (Light) والوضع المظلم (Dark Mode).

### 🚨 أكثر الملفات تضرراً وتحتوي على ألوان ثابتة:
الرقم بجانب كل ملف يعبر عن عدد مرات استخدام لون ثابت بشكل خاطئ داخل الملف:

1. `driver_wallet_screen.dart` **(79 مشكلة)**
2. `driver_trips_screen.dart` **(68 مشكلة)**
3. `location_selection_screen.dart` **(58 مشكلة)**
4. `trip_details_screen.dart` للعميل **(47 مشكلة)**
5. `user_wallet_screen.dart` **(46 مشكلة)**
6. `pricing_screen.dart` **(38 مشكلة)**
7. `messages_screen.dart` **(30 مشكلة)**
8. `searching_screen.dart` **(27 مشكلة)**
9. `app_drawer.dart` **(26 مشكلة)**
10. `meeting_point_screen.dart` **(24 مشكلة)**

### 🎨 الألوان الأكثر استخداماً والتي تكسر الوضع الليلي:
* `Colors.white` (حوالي **184** مرة): تظهر ساطعة جداً في الوضع الليلي إذا استخدمت كخلفية، أو تختفي إذا كانت خلفية الشاشة بيضاء في الوضع النهاري.
* `Colors.black` (حوالي **57** مرة): تسبب اختفاء النصوص عندما تصبح خلفية الشاشة داكنة في الوضع الليلي.
* ألوان Hex صريحة مثل `Color(0xFF0D1526)` و `Color(0xFF10B981)` متناثرة في الكود بدلاً من استدعائها من الـ Theme.
* استخدام `AppColors.background` مباشرة في الشاشات (وهو مصمم للوضع الداكن فقط).

### 💡 خطوات الحل الجذري المطلوب تنفيذها:

لقد قمت مسبقاً بتعريف إضافة ممتازة (Extension) في ملف `theme_extensions.dart` اسمها `AppThemeX`. هذا هو مفتاح الحل.

1. **لخلفيات الشاشات والحاويات (Containers):**
   - ❌ **احذف:** `color: Colors.white` أو `color: AppColors.background`
   - ✅ **استبدل بـ:** `color: context.bgColor` أو `color: context.cardColor`

2. **للنصوص (Texts) والأيقونات (Icons):**
   - ❌ **احذف:** `color: Colors.black` أو `color: Colors.white`
   - ✅ **استبدل بـ:** `color: context.textPrimary` أو `color: context.textSecondary`

3. **للفواصل (Dividers):**
   - ❌ **احذف:** `Colors.grey[300]` أو `Colors.white.withValues(...)`
   - ✅ **استبدل بـ:** `color: context.divColor`

4. **تعديل الشفافية (Opacity):**
   - بدلاً من استخدام `Colors.white.withOpacity(0.1)` استخدم `context.textPrimary.withValues(alpha: 0.1)` لتتوافق الألوان بشفافيتها في الوضعين.

**الخلاصة:**
من أجل دعم الـ Dark Mode بنسبة 100%، يجب المرور على الشاشات المذكورة في القائمة أعلاه (بدءاً بشاشات الـ Wallet والـ Trips) واستبدال الألوان المباشرة بخصائص الـ `context` المتوفرة في `theme_extensions.dart`.
