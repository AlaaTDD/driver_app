# 📬 تقرير التحليل العميق — نظام الرسائل (Messaging System)
> **المشروع:** تطبيق Flutter + Supabase (User & Driver App)  
> **تاريخ التحليل:** 2026-05-05  
> **الملفات المُحلَّلة:** `messages_screen.dart` · `messages_repository.dart` · `message_model.dart` · `support_message_model.dart` · `app_router.dart` · `user_presence_service.dart` · `fcm_service.dart` · `complaints_repository.dart` · `chatbot_repository.dart` · `Supabase Schema CSV (939 rows)`

---

## 1. 🗺️ خريطة الملفات المتعلقة بالرسائل

```
lib/
├── core/
│   └── models/
│       ├── message_model.dart            ✅ موجود
│       └── support_message_model.dart    ✅ موجود
│
├── services/
│   ├── fcm_service.dart                  ✅ موجود
│   └── user_presence_service.dart        ✅ موجود
│
└── features/
    └── shared/
        └── presentation/
            ├── messages/
            │   ├── messages_screen.dart           ✅ موجود (ConversationsScreen + MessagesScreen)
            │   └── data/
            │       └── messages_repository.dart   ✅ موجود
            ├── chatbot/
            │   ├── chatbot_screen.dart            ✅ موجود
            │   └── data/
            │       └── chatbot_repository.dart    ✅ موجود
            └── screens/
                ├── complaints_screen.dart         ✅ موجود
                └── complaints_repository.dart     ✅ موجود
```

### ما هو غائب تمامًا (ملفات مفقودة منطقيًا):
```
lib/features/shared/presentation/messages/
├── bloc/                          ❌ غائب — لا يوجد BLoC للرسائل
│   ├── messages_bloc.dart
│   ├── messages_event.dart
│   └── messages_state.dart
└── widgets/
    ├── message_bubble.dart        ❌ مدمج في الشاشة مباشرة (مش منفصل)
    ├── conversation_tile.dart     ❌ مدمج في الشاشة مباشرة
    └── typing_indicator.dart      ❌ غائب
```

---

## 2. 🗄️ تحليل قاعدة البيانات (Database Schema)

### جدول `messages` — الهيكل الفعلي

| العمود | النوع | Nullable | القيمة الافتراضية | ملاحظات |
|--------|-------|----------|-------------------|---------|
| `id` | uuid | ❌ | `gen_random_uuid()` | PK |
| `sender_id` | uuid | ❌ | — | FK → users.id CASCADE DELETE |
| `receiver_id` | uuid | ❌ | — | FK → users.id CASCADE DELETE |
| `trip_id` | uuid | ✅ | NULL | FK → trips.id **SET NULL** on delete |
| `content` | text | ❌ | — | نص الرسالة |
| `is_read` | bool | ✅ | `false` | هل قرأ المُستقبِل الرسالة |
| `created_at` | timestamptz | ✅ | `now()` | وقت الإنشاء |

**CHECK Constraint:** `sender_id <> receiver_id` ✅ صحيح

### جدول `support_messages` — الهيكل الفعلي

| العمود | النوع | Nullable | القيمة الافتراضية |
|--------|-------|----------|-------------------|
| `id` | uuid | ❌ | `gen_random_uuid()` |
| `user_id` | uuid | ❌ | — | FK → users.id CASCADE |
| `message` | text | ❌ | — |
| `sender_role` | varchar(20) | ✅ | `'user'` |
| `created_at` | timestamptz | ✅ | `now()` |

### جدول `notifications` — الهيكل الفعلي

| العمود | النوع | Nullable | ملاحظات |
|--------|-------|----------|---------|
| `id` | uuid | ❌ | PK |
| `user_id` | uuid | ❌ | FK → users.id CASCADE |
| `title` | varchar(255) | ❌ | عنوان بالإنجليزية |
| `message` | text | ❌ | نص الإشعار |
| `type` | varchar(50) | ✅ | أنواع محددة (CHECK) |
| `reference_id` | uuid | ✅ | مثلاً trip_id |
| `is_read` | bool | ✅ | `false` |
| `created_at` | timestamptz | ✅ | `now()` |
| `title_ar` | varchar(255) | ✅ | عنوان عربي (إضافة لاحقة) |
| `body_ar` | text | ✅ | نص عربي (إضافة لاحقة) |

**أنواع الإشعارات (CHECK):** `general`, `trip`, `promo`, `system`, `trip_offer`, `offer_accepted`, `driver_arriving`, `trip_started`, `trip_completed`, `trip_cancelled`, `no_drivers`, `new_message`, `account_verified`

---

## 3. 🔴 المشاكل الحرجة (Critical Issues)

### 3.1 — مشكلة أداء كارثية في `subscribeToDirectMessages`

```dart
// ❌ الكود الحالي — خطر حقيقي على الأداء
return SupabaseService.client
    .from('messages')
    .stream(primaryKey: ['id'])
    .order('created_at', ascending: true)
    .map((data) => data
        .where((row) {
          // يجلب كل الرسائل من الداتابيز ويفلتر على الـ client!
          final s = row['sender_id'];
          final r = row['receiver_id'];
          final tid = row['trip_id'];
          return tid == null &&
              ((s == userId && r == otherUserId) ||
               (s == otherUserId && r == userId));
        })...
```

**السبب:** Supabase Realtime `.stream()` لا يدعم `.or()` filter، فالكود يجلب **كل الرسائل في الجدول** ويفلتر على جهاز المستخدم.

**الحل المطلوب:**
```dart
// ✅ الحل الصح — استخدام channel مباشر بدلاً من .stream()
final channel = SupabaseService.client
    .channel('direct-$userId-$otherUserId')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: FilterType.eq,
        column: 'sender_id',
        value: otherUserId,
      ),
      callback: (payload) => handleNewMessage(payload),
    )
    .subscribe();
```

---

### 3.2 — حالة "online" وهمية (Fake Online Status)

```dart
// ❌ في messages_screen.dart — الـ online status ثابت دايمًا
Container(
  width: 7, height: 7,
  decoration: const BoxDecoration(
    color: AppColors.success,  // أخضر دايمًا!
    shape: BoxShape.circle,
  ),
),
Text(l.online, style: const TextStyle(color: AppColors.success)),
```

المشكلة: يعرض المستخدم دايمًا "online" حتى لو كان offline تمامًا. `UserPresenceService` موجود في الكود وبيتعامل مع `user_presence` table، لكن **لم يُربط بواجهة الرسائل أبدًا**.

---

### 3.3 — مشكلة أمنية: FCM Push من الـ Client مباشرة

```dart
// ❌ في messages_repository.dart
await SupabaseService.client.functions.invoke('send-fcm', body: {
  'user_id': receiverId,  // أي user_id!
  'title': title,
  'body': text,
  'data': data,
});
```

إذا كانت Edge Function `send-fcm` لا تتحقق من JWT وتتأكد أن المُرسِل هو فعلاً صاحب الـ token، فيمكن لأي مستخدم إرسال push notification لأي مستخدم آخر بأي محتوى.

**الحل:** التحقق في Edge Function:
```javascript
// في send-fcm Edge Function
const { user } = await supabase.auth.getUser(jwt);
if (user.id !== body.sender_id) {
  return new Response("Unauthorized", { status: 403 });
}
```

---

### 3.4 — جدول `messages` فارغ تمامًا في Production

**من إحصائيات الداتابيز:**
```
messages: { rows: { live: 0, dead: 0, estimated: 0 }, operations: { inserts: 0 } }
```

الجدول عنده **73 رحلة** في `trips` لكن صفر رسائل — يعني الفيتشر مطلوع لكن لسه محدش اتكلم عبره. ده بيأكد إن الفيتشر لسه قيد الاختبار.

---

## 4. 🟠 مشاكل متوسطة الخطورة (Medium Issues)

### 4.1 — عدم استخدام الصورة الشخصية (Avatar) في القائمة

```dart
// ❌ في messages_repository.dart — بيجيب avatar_url لكن...
final users = await SupabaseService.client
    .from('users')
    .select('id, name, avatar_url, role')  // avatar_url موجود في الـ query
    .inFilter('id', otherIds);

// ❌ في _ConversationTile — مش بيستخدمها أبدًا!
CircleAvatar(
  child: Icon(
    isDriver ? Icons.drive_eta_rounded : Icons.person_rounded,  // أيقونة ثابتة!
  ),
),
```

`AppCachedImage` widget موجود في `lib/core/widgets/app_cached_image.dart` لكنه لم يُستخدم هنا.

---

### 4.2 — منطق حساب `isRead` مُربك

```dart
// ❌ كود صعب القراءة ومحتمل أخطاء
isRead: conv['is_me_sender'] as bool? ?? true
    ? true
    : conv['is_read'] as bool? ?? false,
```

إذا كانت `is_me_sender = null` (حالة غير متوقعة)، تعتبرها `true` بسبب `?? true`، فيُعرض المحادثة كمقروءة حتى لو لم تكن كذلك. الكود يحتاج إعادة كتابة واضحة.

```dart
// ✅ الكود الواضح
final iAmSender = conv['is_me_sender'] as bool? ?? false;
final isReadByOther = conv['is_read'] as bool? ?? false;
final isRead = iAmSender || isReadByOther;
```

---

### 4.3 — `_markAsRead` لا يُنتظر (Fire and Forget)

```dart
// ❌ في loadDirectMessages
_markAsRead(otherUserId);  // لا await، لا error handling
```

إذا فشل تحديث `is_read = true`، المستخدم هيفضل يشوف الرسائل كـ "غير مقروءة" حتى في قائمة المحادثات.

---

### 4.4 — تحميل المحادثات مع فتح شات مباشر (Unnecessary Load)

```dart
// ❌ في ConversationsScreen.initState()
if (widget.tripId != null || widget.otherUserId != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _openChat(...);  // بيفتح الشات مباشرة
  });
}
_loadConversations();  // بس برضو بيحمّل قائمة المحادثات بدون داعي!
```

---

### 4.5 — `support_messages` بدون Realtime

من إحصائيات الداتابيز:
```
04_REALTIME: messages → publication: active (INSERT, UPDATE, DELETE)
04_REALTIME: notifications → publication: active
// support_messages: ❌ لا يوجد realtime publication
```

يعني الشاشة الخاصة بالدعم الفني لا تتحدث تلقائيًا عند رد الـ admin — المستخدم محتاج يعمل refresh يدوي.

---

### 4.6 — نص مكتوب بالإنجليزي صريح في كود العربي

```dart
// ❌ في MessagesScreen._buildBody
Text(
  _otherName.isNotEmpty ? 'Say hi to $_otherName! 👋' : '',  // إنجليزي hard-coded!
  style: ...
),
```

---

### 4.7 — مشكلة تكرار الإشعار (Double Notification)

عند إرسال رسالة، يحدث الآتي:
1. يُنشئ `_createNotification()` إشعارًا في جدول `notifications`
2. يُرسل `_sendFcmPush()` push notification عبر FCM

النتيجة: المستخدم يتلقى إشعارين عن نفس الرسالة إذا كان التطبيق يستمع لكلاهما.

---

### 4.8 — CASCADE DELETE خطر على بيانات المستخدم

```sql
-- من schema CSV
messages_sender_id_fkey: ON DELETE CASCADE
messages_receiver_id_fkey: ON DELETE CASCADE
```

إذا حُذف أي مستخدم من جدول `users`، **كل رسائله ستُحذف تلقائيًا** — بما فيها رسائل المستخدم الآخر في نفس المحادثة! هذا يمكن أن يفقد المستخدم الثاني سجل محادثته كاملًا.

---

### 4.9 — `trip_id SET NULL` يُنتج رسائل يتيمة

```sql
messages_trip_id_fkey: ON DELETE SET NULL
```

عند حذف رحلة، رسائل الرحلة تبقى في الجدول لكن `trip_id` يصبح `NULL`. هذه الرسائل ستظهر في الـ `subscribeToDirectMessages` لأن الـ filter يشترط `trip_id == null`!

---

## 5. 🟡 مشاكل الـ UI/UX (Interface Issues)

### 5.1 — حالة الـ online ثابتة (مكررة من Section 3.2 لكن من زاوية UX)

الـ AppBar يعرض نقطة خضراء ونص "online" لكل محادثة. هذا يُضلل المستخدم تمامًا.

**المطلوب:**
- ربط الـ `user_presence` table بشاشة الرسائل
- إضافة stream يُراقب حالة المستخدم الآخر
- عرض "آخر ظهور" إذا كان offline

---

### 5.2 — لا يوجد عداد للرسائل غير المقروءة

قائمة المحادثات تعرض نقطة صغيرة فقط (●) بدون رقم. المستخدم لا يعرف كم رسالة فاتته.

**المطلوب:** إضافة `unread_count` في `loadConversations()`:
```dart
// في messages_repository.dart
'unread_count': data
    .where((row) => row['sender_id'] == otherId && 
                    row['receiver_id'] == userId && 
                    row['is_read'] == false)
    .length,
```

---

### 5.3 — لا يوجد فواصل تاريخ في المحادثة

المحادثة تعرض الرسائل بشكل متسلسل بدون فواصل مثل "اليوم" / "الأمس" / "3 مايو".

---

### 5.4 — زر "العودة للأسفل" غائب

إذا قرأ المستخدم رسائل قديمة وجاء رسالة جديدة، لا يوجد زر للعودة لأحدث رسالة.

---

### 5.5 — لا يوجد مؤشر كتابة (Typing Indicator)

ميزة "الطرف الآخر يكتب..." غائبة تمامًا.

---

### 5.6 — الـ Avatar في فقاعة الرسالة دايمًا icon عام

```dart
// في _ChatBubble
CircleAvatar(
  child: const Icon(Icons.person, size: 18, color: AppColors.primary),  // ثابت!
),
```

---

### 5.7 — لا يوجد Long Press على الرسائل

لا يمكن نسخ أو حذف أو الرد على رسالة معينة.

---

### 5.8 — لا يوجد تأكيد التسليم الحقيقي (Read Receipts)

```dart
// في _ChatBubble
Icon(
  isSending ? Icons.access_time : Icons.done_all,  // ✓✓ دايمًا بعد الإرسال
  // لكن done_all لا يعني أن الطرف الآخر قرأها!
),
```

`done_all` يظهر فور نجاح الإرسال، لكن يُفترض أن يظهر فقط عندما `is_read = true`.

---

## 6. 🔵 ما هو زيادة أو يحتاج مراجعة (Redundant/Overkill)

### 6.1 — مسارات مُكررة في الـ Router

```dart
// في app_router.dart — نفس الشاشة لكل من User وDriver
path: AppRoutes.userMessages,   // يفتح ConversationsScreen
path: AppRoutes.driverMessages, // يفتح ConversationsScreen أيضًا!
```

`ConversationsScreen` هي نفسها للاثنين. هذا جيد من ناحية مشاركة الكود، لكن يمكن دمجهما في route واحد مع parameter يحدد نوع المستخدم.

---

### 6.2 — جلب `avatar_url` بدون استخدامها

في `loadConversations()` يُجلب `avatar_url` من قاعدة البيانات لكن لا يُستخدم أبدًا في الـ UI. هذا بيانات غير ضرورية في كل طلب.

---

### 6.3 — Index مكرر على `messages.trip_id`

من الـ Schema:
```sql
idx_messages_trip_id  → btree(trip_id)        -- scans: 2
idx_messages_trip_created → btree(trip_id, created_at DESC)  -- scans: 0 (unused!)
```

`idx_messages_trip_created` غير مستخدم أبدًا (`scans: 0`) وهو يشمل `idx_messages_trip_id` بالكامل. يمكن حذفه.

---

### 6.4 — بيانات الداتابيز مكررة في الـ Schema CSV

كل صف في جدول `messages` يظهر مرتين في ملف الـ CSV (rows 17-18, 63-64, 97-98...إلخ). هذا يبدو أنه مشكلة في أداة توليد التقرير، ليس في الداتابيز نفسها.

---

## 7. 📋 قائمة المهام المطلوبة (Action Plan)

### 🔴 أولوية عالية جدًا (يجب قبل الإطلاق)

| # | المهمة | الملف |
|---|--------|-------|
| 1 | إصلاح `subscribeToDirectMessages` — استخدام `channel` بدلاً من `.stream()` | `messages_repository.dart` |
| 2 | إزالة "online" الوهمي أو ربطه بـ `user_presence` table | `messages_screen.dart` |
| 3 | تأمين `send-fcm` Edge Function بالتحقق من JWT | Supabase Edge Functions |
| 4 | إضافة index على `(sender_id, receiver_id, created_at)` في `messages` | SQL Migration |
| 5 | إصلاح منطق `isRead` المُربك في `_ConversationTile` | `messages_screen.dart` |
| 6 | إزالة النص الإنجليزي hard-coded ("Say hi to...") | `messages_screen.dart` |
| 7 | حل مشكلة الرسائل اليتيمة بعد `trip_id SET NULL` | SQL Migration + Repository |

### 🟠 أولوية متوسطة (خلال أسبوعين)

| # | المهمة | الملف |
|---|--------|-------|
| 8 | إضافة `unread_count` في قائمة المحادثات | `messages_repository.dart` |
| 9 | استخدام `AppCachedImage` لعرض أفاتار المستخدمين | `messages_screen.dart` |
| 10 | `await _markAsRead()` بشكل صحيح مع error handling | `messages_repository.dart` |
| 11 | إضافة Realtime لـ `support_messages` table | Supabase Dashboard |
| 12 | إزالة تحميل المحادثات عند فتح شات مباشر | `messages_screen.dart` |
| 13 | إصلاح Read Receipts — `done_all` فقط عند `is_read = true` | `messages_screen.dart` |
| 14 | حذف `idx_messages_trip_created` (index غير مستخدم) | SQL Migration |
| 15 | استبدال `CASCADE DELETE` بـ `SET NULL` لحفظ رسائل الطرف الآخر | SQL Migration |

### 🟡 تحسينات UX (خلال شهر)

| # | المهمة |
|---|--------|
| 16 | إضافة فواصل التاريخ في المحادثة ("اليوم"، "أمس"، إلخ) |
| 17 | إضافة زر "العودة لأحدث رسالة" |
| 18 | إضافة مؤشر الكتابة (Typing Indicator) عبر Supabase Presence |
| 19 | إضافة Long Press على الرسائل (نسخ، حذف) |
| 20 | استخراج `_ChatBubble` و `_ConversationTile` لملفات widgets منفصلة |
| 21 | إضافة BLoC لإدارة حالة الرسائل بدلاً من setState المباشر |
| 22 | عدم إرسال بيانات إضافية (`avatar_url`) إذا لم تُستخدم |

---

## 8. 🏗️ الهيكل المقترح للداتابيز بعد الإصلاح

### Migrations المطلوبة:

```sql
-- 1. إضافة index للرسائل المباشرة
CREATE INDEX IF NOT EXISTS idx_messages_direct
  ON public.messages (sender_id, receiver_id, created_at DESC)
  WHERE trip_id IS NULL;

-- 2. حذف الـ index المكرر غير المستخدم
DROP INDEX IF EXISTS idx_messages_trip_created;

-- 3. تفعيل Realtime لـ support_messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;

-- 4. تغيير cascade delete لحفظ رسائل الطرف الآخر (اختياري - يحتاج تفكير)
-- البديل: استخدام soft delete بعمود deleted_at
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_by_sender boolean DEFAULT false;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS deleted_by_receiver boolean DEFAULT false;

-- 5. إضافة timestamp للتعديل (لدعم read receipts حقيقية)
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at timestamptz;
```

---

## 9. 📊 ملخص نقاط الضعف والقوة

### ✅ نقاط القوة (ما هو شغال صح)
- هيكل الداتابيز سليم ومنطقي (sender/receiver/trip_id)
- RLS مُفعَّل ومحكم على كل الجداول
- Realtime مفعَّل على `messages` و `notifications`
- إرسال FCM push عند كل رسالة (user & driver)
- Optimistic UI عند إرسال الرسائل (تجربة مستخدم جيدة)
- check constraint `sender_id <> receiver_id` يمنع الرسالة لنفسك
- الكود مشترك بين User وDriver (لا تكرار في الشاشات)
- `loadDirectMessages` يُفعِّل `_markAsRead` تلقائيًا عند فتح المحادثة
- إدارة lifecycle في `UserPresenceService` صحيحة (pause/resume)

### ❌ نقاط الضعف الرئيسية
- الـ streaming للرسائل المباشرة كارثي على الأداء
- الـ online status وهمي (مُضلل للمستخدم)
- لا avatar صور في واجهة المحادثات
- لا unread count بالأرقام
- لا realtime لـ support_messages
- نص إنجليزي hard-coded
- مشكلة أمنية محتملة في FCM

---

## 10. 🎯 الخطة الموصى بها للتنفيذ

```
الأسبوع 1: الإصلاحات الحرجة
  ├── إصلاح subscribeToDirectMessages
  ├── إزالة online وهمي
  ├── تأمين FCM Edge Function
  └── SQL migrations (indexes + realtime)

الأسبوع 2: تحسينات الداتابيز والـ Repository
  ├── إضافة unread_count
  ├── إصلاح markAsRead
  ├── إصلاح isRead logic
  └── Avatar images

الأسبوع 3-4: تحسينات UX
  ├── Date separators
  ├── Scroll-to-bottom button
  ├── Real read receipts
  └── Long press actions

الشهر 2: الميزات الجديدة
  ├── Typing Indicator
  ├── Message reactions
  └── BLoC architecture migration
```

---

*تم إنشاء هذا التقرير بناءً على تحليل شامل لـ 304 ملف Dart + 939 صف من Schema الداتابيز*
