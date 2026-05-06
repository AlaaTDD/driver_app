# 🔬 التحليل العميق الشامل — نظام الرسائل والتواصل
> **الإصدار:** v2.0 — تحليل كامل (304 ملف Dart + 939 صف Schema)
> **تاريخ التحليل:** 2026-05-05
> **النطاق:** messages · support_messages · notifications · chatbot · complaints · user_presence · FCM · RLS · Indexes

---

## الفهرس السريع

| القسم | الوصف |
|-------|-------|
| [§1](#1-خريطة-النظام-الكاملة) | خريطة النظام الكاملة |
| [§2](#2-bugs-حرجة-سبق-ما-تكشفت) | Bugs حرجة جديدة — لم تُكتشف سابقًا |
| [§3](#3-مشاكل-الأمان-الخفية) | مشاكل الأمان الخفية |
| [§4](#4-ثغرات-الداتابيز-الدقيقة) | ثغرات الداتابيز الدقيقة |
| [§5](#5-مشاكل-الـ-ui--ux-الخفية) | مشاكل الـ UI/UX الخفية |
| [§6](#6-مشاكل-ما-بين-السطور) | ما بين السطور — المشاكل المخفية |
| [§7](#7-تحليل-مقارن-بين-الشاشات) | تحليل مقارن بين الشاشات |
| [§8](#8-خطة-الإصلاح-الكاملة) | خطة الإصلاح الكاملة |

---

## §1 خريطة النظام الكاملة

### طبقات التواصل في التطبيق

```
┌─────────────────────────────────────────────────────────┐
│              أنواع التواصل في التطبيق                   │
├─────────────┬──────────────┬───────────┬────────────────┤
│  Messages   │ Support Chat │  Chatbot  │  Notifications │
│ (direct/    │ (user↔admin) │ (AI)      │  (system)      │
│  trip)      │              │           │                │
├─────────────┼──────────────┼───────────┼────────────────┤
│ messages    │support_msg   │support_msg│ notifications  │
│ table       │ table        │ + AI API  │  table         │
│ Realtime✅  │ No RT ❌     │ No RT ❌  │  Realtime ✅   │
└─────────────┴──────────────┴───────────┴────────────────┘
```

### الملفات ومسؤوليتها

| الملف | المسؤولية | الحالة |
|-------|-----------|--------|
| `messages_screen.dart` | ConversationsScreen + MessagesScreen + Widgets | ⚠️ مشاكل |
| `messages_repository.dart` | Direct/Trip CRUD + Realtime + FCM | ⚠️ مشاكل |
| `message_model.dart` | نموذج الرسالة | ✅ |
| `support_message_model.dart` | نموذج دعم فني | ✅ |
| `chatbot_screen.dart` | شاشة الـ AI Chatbot | ⚠️ مشاكل |
| `chatbot_repository.dart` | AI API calls + support_messages CRUD | 🔴 مشاكل حرجة |
| `notifications_repository.dart` | تحميل وإدارة الإشعارات | ⚠️ مشاكل |
| `notifications_screen.dart` | عرض الإشعارات | ⚠️ مشاكل |
| `complaints_screen.dart` | عرض وإنشاء الشكاوى | 🔴 Bug حرج |
| `complaints_repository.dart` | Complaints CRUD | 🔴 Bug حرج |
| `fcm_service.dart` | Firebase notifications | 🔴 مشاكل حرجة |
| `user_presence_service.dart` | تتبع حالة المستخدمين | ⚠️ غير مربوط |

---

## §2 Bugs حرجة — لم تُكتشف سابقًا

### 🔴 BUG #1 — `complaints.trip_id` NOT NULL vs كود يبعت NULL

**هذا Bug سيؤدي إلى crash فوري في production**

```dart
// في complaints_repository.dart
Future<void> submitComplaint({
  required String title,
  required String description,
  String? tripId,  // ← nullable في الكود
}) async {
  await SupabaseService.client.from('complaints').insert({
    'user_id': user?.id,
    if (tripId != null) 'trip_id': tripId,  // ← مش بيتبعت لو null
    'title': title.trim(),
    ...
  });
}
```

```sql
-- من الـ Schema:
complaints.trip_id: nullable=False  ← NOT NULL في الداتابيز!
```

**ماذا يحدث؟** لما المستخدم يفتح شاشة الشكاوى من غير رحلة محددة (من الـ Drawer مثلًا)، الكود هيبعت INSERT بدون `trip_id`، والداتابيز هترفض بـ `null value in column "trip_id" violates not-null constraint`.

**الإصلاح المطلوب — خيارين:**
```sql
-- Option A: تغيير الـ DB ليقبل NULL
ALTER TABLE public.complaints ALTER COLUMN trip_id DROP NOT NULL;

-- Option B: إجبار المستخدم يختار رحلة قبل الشكوى (UI change)
```

---

### 🔴 BUG #2 — تاب على إشعار `new_message` لا يفتح شاشة الرسائل

```dart
// في fcm_service.dart
Future<void> _handleMessageOpen(RemoteMessage message) async {
  final type = message.data['type'] ?? message.data['notification_type'];
  if (type == 'ride_offer') {
    developer.log('🔥 FCM OPENED APP: User tapped ride_offer notification!');
    // Typically you'd navigate to the trip details page here.
  }
  // ❌ لا يوجد case لـ 'new_message'
  // ❌ لا يوجد case لأي نوع آخر!
}
```

**ماذا يحدث؟** لما المستخدم يضغط على notification "رسالة جديدة من أحمد"، التطبيق يفتح على الصفحة الرئيسية ولا شيء يحدث. المستخدم لا يُوجَّه للمحادثة.

**الإصلاح المطلوب:**
```dart
Future<void> _handleMessageOpen(RemoteMessage message) async {
  final type = message.data['type'];
  final router = // inject GoRouter
  
  switch (type) {
    case 'new_message':
      final senderId = message.data['senderId'];
      final tripId = message.data['tripId'];
      router.go(
        tripId != null 
          ? '/user/messages?tripId=$tripId'
          : '/user/messages?otherUserId=$senderId'
      );
      break;
    case 'ride_offer':
      // existing handling
      break;
  }
}
```

---

### 🔴 BUG #3 — AI API Key مكشوفة في APK

```dart
// في chatbot_repository.dart
final response = await http.post(
  Uri.parse(EnvConstants.aiApiUrl),
  headers: {
    'Authorization': 'Bearer ${EnvConstants.openRouterApiKey}', // ← مكشوفة!
    'Content-Type': 'application/json',
  },
  ...
);
```

```dart
// في env_constants.dart (مستنتج من الاستخدام)
static String get openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
```

**المشكلة:** حتى لو الـ key في `.env` ملفوش في الـ repo، لما التطبيق يتبنى للـ release، الـ `dotenv` بيضم الـ `.env` كـ asset في الـ APK. أي شخص يفتح الـ APK بـ `apktool` يشوف الـ key مباشرة.

**الإصلاح:** نقل AI calls لـ Supabase Edge Function بدلاً من الاستدعاء المباشر.

---

### 🔴 BUG #4 — AI رد يُحفظ كـ "user" مش كـ "support"

```dart
// في chatbot_repository.dart
Future<void> saveSupportReply(String reply) async {
  final userId = SupabaseService.currentUser?.id;  // ← user_id الحالي!
  
  await SupabaseService.client.from('support_messages').insert({
    'user_id': userId,           // ← user_id = المستخدم نفسه
    'message': reply,
    'sender_role': 'support',    // ← لكن role = support
  });
}
```

**وفي RLS:**
```sql
-- Users can send support messages
WITH CHECK: (auth.uid() = user_id)
```

**المشكلة:** الـ RLS بيتحقق إن `auth.uid() = user_id` — هذا صحيح لأن الكود بيحط `user_id` الخاص بالمستخدم. لكن المعنى الدلالي غلط: رد الـ AI يبان كأنه جاء "من المستخدم نفسه بـ role=support". لو الـ admin فتح الـ support_messages في dashboard، هيشوف المستخدم كأنه بيرد على نفسه.

---

### 🔴 BUG #5 — `NotificationsScreen` يحمل كل الإشعارات بعد كل markAsRead

```dart
// في notifications_screen.dart
Future<void> _markAsRead(String notificationId) async {
  try {
    await _repository.markAsRead(notificationId);
    _loadNotifications(); // ← يعمل reload كامل من السيرفر!
  } catch (e) { ... }
}
```

لو المستخدم عنده 100 إشعار وضغط على واحد، هيحمل الـ 100 من جديد بدل تحديث الـ local state فقط.

**الإصلاح:**
```dart
Future<void> _markAsRead(String notificationId) async {
  await _repository.markAsRead(notificationId);
  // local update بدون reload
  setState(() {
    _notifications = _notifications.map((n) =>
      n.id == notificationId ? n.copyWith(isRead: true) : n
    ).toList();
  });
}
```

---

### 🔴 BUG #6 — `getUnreadCountStream` يجلب كل الإشعارات ويعد client-side

```dart
// في notifications_repository.dart
Stream<int> getUnreadCountStream(String userId) {
  return SupabaseService.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((rows) => rows.where((r) => r['is_read'] == false).length); // ← عد client-side
}
```

**المشكلة:** `.stream()` يجلب **كل إشعارات المستخدم** كل مرة تتغير أي إشعار، وبعدين يعدها. لو المستخدم عنده 500 إشعار، كل insert/update في الجدول يجلب 500 صف.

**الإصلاح:**
```sql
-- استخدام PostgreSQL aggregate عبر RPC
CREATE OR REPLACE FUNCTION get_unread_count(p_user_id uuid)
RETURNS integer AS $$
  SELECT COUNT(*)::integer FROM notifications 
  WHERE user_id = p_user_id AND is_read = false;
$$ LANGUAGE sql SECURITY DEFINER;
```

---

### 🟠 BUG #7 — `ChatbotScreen` بدون `TextInputAction.send`

```dart
// في messages_screen.dart ✅
TextField(
  textInputAction: TextInputAction.send,
  onSubmitted: (_) => _sendMessage(),
  ...
)

// في chatbot_screen.dart ❌
TextField(
  controller: _controller,
  // لا يوجد textInputAction!
  // لا يوجد onSubmitted!
  ...
)
```

المستخدم في الـ Chatbot لا يستطيع الإرسال بضغط Enter — عكس المتوقع وعكس screens الأخرى.

---

### 🟠 BUG #8 — `loadConversations()` بدون pagination

```dart
// في messages_repository.dart
final data = await SupabaseService.client
    .from('messages')
    .select('id, sender_id, receiver_id, content, created_at, is_read')
    .or('sender_id.eq.$userId,receiver_id.eq.$userId')
    .order('created_at', ascending: false);
// ❌ لا يوجد .limit() أو pagination
```

لو مستخدم عنده 1000 رسالة، كلها هتتحمل في الذاكرة لبناء قائمة 5 محادثات.

---

## §3 مشاكل الأمان الخفية

### 🔴 SEC-1 — `rls_forced = false` على كل الجداول

```
messages:          rls_forced=False
notifications:     rls_forced=False
support_messages:  rls_forced=False
user_presence:     rls_forced=False
-- (وكل الجداول الأخرى)
```

**ماذا يعني هذا؟** `rls_forced = false` يعني إن الـ `postgres` superuser و service_role يتجاوزان الـ RLS تلقائيًا. هذا تصميم Supabase الافتراضي وليس خطأ في حد ذاته، **لكن** إذا كانت أي Edge Function أو Background Job تستخدم `service_role` key، يمكنها قراءة أو تعديل أي بيانات بدون قيود RLS.

**التوصية:** مراجعة كل Edge Function للتأكد من عدم استخدام `service_role` إلا في عمليات محددة.

---

### 🔴 SEC-2 — `anon` role عنده كامل الصلاحيات على جداول حساسة

```
messages → anon: [DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE]
notifications → anon: [DELETE, INSERT, REFERENCES, SELECT, ...]
support_messages → anon: [DELETE, INSERT, ...]
user_presence → anon: [DELETE, INSERT, ...]
```

RLS مفعَّل ويحمي، لكن هذا يعني إن أي طلب بدون token (anonymous) يحاول مهاجمة الـ RLS policies مباشرة. **أفضل ممارسة** هي إزالة كل صلاحيات `anon` من الجداول الحساسة.

```sql
-- الإصلاح
REVOKE ALL ON public.messages FROM anon;
REVOKE ALL ON public.notifications FROM anon;
REVOKE ALL ON public.support_messages FROM anon;
REVOKE ALL ON public.user_presence FROM anon;
```

---

### 🔴 SEC-3 — `user_presence` مرئي لكل أحد بدون authentication

```sql
-- RLS Policy:
Anyone can read presence: SELECT using=true
```

يعني: أي شخص (حتى غير مسجل) يمكنه رؤية مواقع وآخر نشاط كل مستخدمي التطبيق. هذا خطر على الخصوصية خاصة للمستخدمين الذين يريدون إخفاء موقعهم.

**الإصلاح:**
```sql
-- تغيير من anyone إلى authenticated فقط
DROP POLICY IF EXISTS "Anyone can read presence" ON public.user_presence;
CREATE POLICY "Authenticated can read presence"
  ON public.user_presence FOR SELECT
  TO authenticated
  USING (true);
```

---

### 🟠 SEC-4 — لا يوجد Rate Limiting على إرسال الرسائل

```dart
// في messages_repository.dart
Future<void> sendDirectMessage({...}) async {
  // ❌ لا يوجد debounce
  // ❌ لا يوجد rate limit
  // ❌ لا يوجد cooldown
  await SupabaseService.client.from('messages').insert({...});
  await _sendFcmPush(...);  // FCM بدون حد
}
```

مستخدم يمكنه إرسال آلاف الرسائل في ثانية، مما يؤدي لـ spam في الـ DB وفي FCM.

---

### 🟠 SEC-5 — Chatbot بدون Rate Limiting على AI API

```dart
// chatbot_repository.dart
Future<String?> fetchAiReply(String text) async {
  // ❌ لا يوجد حد للاستخدام
  // مستخدم يمكنه إرسال 1000 رسالة في دقيقة
  // كل رسالة = استدعاء AI مدفوع!
  final response = await http.post(Uri.parse(EnvConstants.aiApiUrl), ...);
}
```

---

## §4 ثغرات الداتابيز الدقيقة

### 🔴 DB-1 — Missing Index على `notifications(user_id)`

```sql
-- الـ query الأساسي في loadNotifications():
SELECT * FROM notifications
WHERE user_id = $1                -- ← لا يوجد index على user_id وحده!
ORDER BY created_at DESC;

-- الـ indexes الموجودة:
idx_notifications_created_at   → created_at DESC          (لا يشمل user_id)
idx_notifications_is_read      → is_read                  (لا يشمل user_id)
idx_notifications_user_unread  → user_id, created_at WHERE is_read=false  (partial - فقط للغير مقروء)

-- ❌ لا يوجد: INDEX ON notifications(user_id, created_at DESC)
```

كل `loadNotifications()` بيعمل sequential scan على الجدول كله.

**الإصلاح:**
```sql
CREATE INDEX idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);
```

---

### 🔴 DB-2 — Missing Index على `messages(sender_id, receiver_id)` للمحادثات المباشرة

```sql
-- الـ queries المستخدمة في الكود:
-- Query 1: loadDirectMessages
SELECT * FROM messages
WHERE (sender_id=$1 AND receiver_id=$2) OR (sender_id=$2 AND receiver_id=$1)
AND trip_id IS NULL
ORDER BY created_at ASC;

-- Query 2: loadConversations (OR filter)
SELECT * FROM messages
WHERE sender_id=$1 OR receiver_id=$1
ORDER BY created_at DESC;

-- الـ indexes الموجودة للـ messages:
idx_messages_trip_id           → trip_id
idx_messages_trip_created      → trip_id, created_at DESC  (unused!)
messages_pkey                  → id

-- ❌ لا يوجد index على sender_id أو receiver_id وحدها!
```

**الإصلاح:**
```sql
-- للمحادثات المباشرة
CREATE INDEX idx_messages_direct_chat
  ON public.messages (sender_id, receiver_id, created_at ASC)
  WHERE trip_id IS NULL;

-- لقائمة المحادثات (loadConversations)
CREATE INDEX idx_messages_sender
  ON public.messages (sender_id, created_at DESC);
CREATE INDEX idx_messages_receiver
  ON public.messages (receiver_id, created_at DESC);
```

---

### 🟠 DB-3 — Index `idx_messages_trip_created` غير مستخدم (0 scans)

```sql
-- موجود لكن لا أحد يستخدمه:
idx_messages_trip_created: 0 scans
-- بينما:
idx_messages_trip_id: 2 scans ✅
```

هذا الـ index موجود بالفعل في تحليلنا السابق، لكن ما قلناه هو: يجب حذفه لأنه يستهلك مساحة ويُبطئ الـ INSERT بدون فائدة.

---

### 🟠 DB-4 — Index `idx_notifications_user_unread` غير مستخدم (0 scans)

```sql
-- partial index موجود لكن 0 scans:
idx_notifications_user_unread: (user_id, created_at DESC) WHERE is_read=false
```

`getUnreadCountStream` يستخدم `.stream()` وليس SQL مباشر، لذا لا يستفيد من هذا الـ index.

---

### 🟠 DB-5 — `support_messages` بدون Realtime Publication

من تحليل الـ Schema:
```
REALTIME TABLES: drivers_profile, messages, notifications, trip_offers, trips, user_presence, vehicle_types
-- support_messages: ❌ غائبة!
```

شاشة الـ Chatbot تعتمد على polling فقط — ردود الـ admin لا تظهر تلقائيًا.

---

### 🟠 DB-6 — Indexes غير مستخدمة كثيرة (overhead بدون فائدة)

```sql
-- كلها 0 scans — أوزان زيادة على كل INSERT:
idx_messages_trip_created         ← حذف
idx_notifications_user_unread     ← مراجعة
uq_ratings_trip_user              ← مراجعة
uq_trip_offers_trip_driver        ← مراجعة
idx_trips_payment_wallet          ← مراجعة
idx_users_email, idx_users_phone  ← مراجعة
idx_user_coupons_coupon_id        ← مراجعة
```

---

### 🔵 DB-7 — `messages` و `notifications` في Production لها 0 rows

```
messages:      { live: 0, inserts: 0 }
notifications: { live: 0, inserts: 0 }
```

الفيتشر الكامل لم يُختبر في production. هذا يعني الـ indexes و RLS لم تُختبر تحت load حقيقي.

---

## §5 مشاكل الـ UI / UX الخفية

### 🔴 UX-1 — `NotificationsScreen` لا تتعامل مع نوع `new_message`

```dart
// في notifications_screen.dart
IconData _getNotificationIcon(String? type) {
  switch (type) {
    case 'trip': return Icons.directions_car;
    case 'promo': return Icons.local_offer;
    case 'system': return Icons.info;
    default: return Icons.notifications; // ← new_message يقع هنا!
  }
}
```

إشعار "رسالة جديدة" يُعرض بأيقونة جرس عامة. لا توجد أيقونة محادثة ولا navigation للمحادثة عند الضغط عليه.

**الإصلاح:**
```dart
case 'new_message': return Icons.chat_bubble_rounded;
// + إضافة navigation عند tap
void _onNotificationTap(NotificationModel n) {
  if (n.type == 'new_message' && n.referenceId != null) {
    context.go('/user/messages?otherUserId=${n.referenceId}');
  }
}
```

---

### 🟠 UX-2 — تحديث الـ Drawer لا يعكس عداد الرسائل غير المقروءة

```dart
// في app_drawer.dart
_NavItem(
  icon: Icons.chat_bubble_rounded,
  label: l.messages,
  onTap: onMessagesTap,
  // ❌ لا يوجد badge أو عداد للرسائل غير المقروءة
)
```

المستخدم لا يعرف أن عنده رسائل جديدة إلا بعد فتح شاشة المحادثات.

---

### 🟠 UX-3 — `Drawer` header يعرض الصورة كـ initials فقط لو لم تُحمَّل Avatar

```dart
// في _Header في app_drawer.dart
Container(
  child: Center(
    child: Text(
      _initials(name),  // ← دايمًا initials حتى لو في avatar_url
      ...
    ),
  ),
),
```

حتى لو المستخدم حمَّل صورة شخصية، الـ Drawer لا يعرضها.

---

### 🟠 UX-4 — Chatbot يجلب السجل كله عند كل فتح بدون pagination

```dart
// في chatbot_repository.dart
final data = await SupabaseService.client
    .from('support_messages')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', ascending: true);
// ❌ لا يوجد .limit()
```

لو المستخدم أرسل 200 رسالة للدعم الفني، كلها تُحمَّل.

---

### 🟠 UX-5 — `chatbot_screen.dart` يستخدم `cardColor` للـ input bar

```dart
// chatbot_screen.dart
Container(
  color: context.cardColor,  // ← cardColor
  ...
)

// messages_screen.dart  
Container(
  color: context.elevatedColor,  // ← elevatedColor
  ...
)
```

عدم اتساق في الـ design tokens بين الشاشتين.

---

### 🟡 UX-6 — `MessagesScreen` يعرض "Say hi to name! 👋" بالإنجليزي

```dart
// في _buildBody
Text(
  _otherName.isNotEmpty ? 'Say hi to $_otherName! 👋' : '',
  // ❌ hard-coded English — التطبيق عربي بالأساس
)
```

---

### 🟡 UX-7 — `ConversationsScreen` يُحمِّل قائمة المحادثات حتى لو مش محتاجها

```dart
// في initState
if (widget.tripId != null) {
  WidgetsBinding.instance.addPostFrameCallback((_) => _openChat(tripId: widget.tripId));
}
// ← يفتح شات مباشرة، لكن...
_loadConversations(); // ← لا يزال يُحمِّل القائمة بدون داعي!
```

---

### 🟡 UX-8 — لا فواصل تاريخ في محادثة الرسائل

لا يوجد فاصل "اليوم" / "أمس" / "3 مايو" في قائمة الرسائل.

---

### 🟡 UX-9 — لا زر للتمرير لأحدث رسالة

عند قراءة رسائل قديمة وصول رسالة جديدة، لا يوجد FAB أو مؤشر للعودة للأسفل.

---

## §6 ما بين السطور — المشاكل المخفية

### 🔴 HIDDEN-1 — Online Status مبني على Presence لكن غير مربوط بالـ Chat

```dart
// user_presence table columns:
// user_id | lat | lng | last_seen

// UserPresenceService يُحدِّث last_seen كل 5 ثوانٍ ✅
// لكن messages_screen.dart لا يستعلم عن last_seen أبدًا ❌
```

**الوضع الصح:** Online status = `last_seen > NOW() - INTERVAL '30 seconds'`

```dart
// الكود الغائب اللي المفروض يبقى موجود:
Future<bool> isUserOnline(String userId) async {
  final result = await SupabaseService.client
      .from('user_presence')
      .select('last_seen')
      .eq('user_id', userId)
      .maybeSingle();
  
  if (result == null) return false;
  final lastSeen = DateTime.parse(result['last_seen']);
  return DateTime.now().difference(lastSeen).inSeconds < 30;
}

// أو stream للتحديث الفوري:
Stream<bool> watchOnlineStatus(String userId) {
  return SupabaseService.client
      .from('user_presence')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', userId)
      .map((rows) {
        if (rows.isEmpty) return false;
        final lastSeen = DateTime.parse(rows.first['last_seen']);
        return DateTime.now().difference(lastSeen).inSeconds < 30;
      });
}
```

---

### 🔴 HIDDEN-2 — `subscribeToDirectMessages` يجلب كل الداتابيز

```dart
// الكود الحالي
return SupabaseService.client
    .from('messages')
    .stream(primaryKey: ['id'])
    .order('created_at', ascending: true)
    // ❌ لا يوجد filter هنا!
    .map((data) => data.where((row) {
      // يفلتر 10,000 رسالة على جهاز المستخدم
    }));
```

**لماذا حدث هذا؟** لأن Supabase `.stream()` لا يدعم `.or()` filter. الحل الصح:

```dart
Stream<List<MessageModel>> subscribeToDirectMessages(String otherUserId) {
  final userId = SupabaseService.currentUser!.id;
  
  // استخدام channel مع filter على sender أو receiver
  final controller = StreamController<List<MessageModel>>();
  
  // Load initial data
  loadDirectMessages(otherUserId).then((msgs) => controller.add(msgs));
  
  // Subscribe to new messages only (INSERT events)
  final channel = SupabaseService.client
      .channel('dm-$userId-$otherUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: FilterType.eq,
          column: 'sender_id',
          value: otherUserId,  // فقط رسائل الطرف الآخر
        ),
        callback: (payload) {
          final msg = MessageModel.fromJson(payload.newRecord);
          // append to current list
        },
      )
      .subscribe();
  
  return controller.stream;
}
```

---

### 🟠 HIDDEN-3 — Chatbot يُرسل فقط آخر رسالة للـ AI بدون context

```dart
// في chatbot_repository.dart
body: jsonEncode({
  'messages': [
    {'role': 'system', 'content': 'You are a helpful taxi app support assistant...'},
    {'role': 'user', 'content': text},  // ← فقط الرسالة الأخيرة!
    // ❌ لا يوجد conversation history
  ],
}),
```

الـ AI لا يتذكر ما قاله المستخدم في الرسائل السابقة. كل رسالة منفصلة تمامًا عن السياق.

---

### 🟠 HIDDEN-4 — `sendTripMessage` و `sendDirectMessage` يُرسلان إشعارًا مزدوجًا

```dart
// كلاهما يفعل هذا:
await _createNotification(...);  // ← DB notification
await _sendFcmPush(...);         // ← FCM push
```

إذا كان التطبيق مفتوحًا (foreground):
- `_createNotification` → يظهر في notifications screen
- `_sendFcmPush` → `_handleForegroundMessage` → يعرض local notification

النتيجة: **نوتيفيكيشن مرئي مرتين** — مرة في الـ in-app notification bell، ومرة كـ system notification.

**الإصلاح:** في حالة الـ foreground، تجنب إرسال FCM أو تجنب الإشعار المحلي.

---

### 🟠 HIDDEN-5 — `_markAsRead` تعمل بـ `senderId` لكن يجب فلترة `is_read=false` مع `trip_id`

```dart
Future<void> _markAsRead(String senderId) async {
  await SupabaseService.client
      .from('messages')
      .update({'is_read': true})
      .eq('sender_id', senderId)
      .eq('receiver_id', userId)
      .eq('is_read', false);
  // ❌ لا يوجد فلتر على trip_id
}
```

**المشكلة:** إذا فتح المستخدم محادثة مباشرة مع السائق، هذا الكود سيُعلِّم كل الرسائل من هذا السائق كمقروءة — **بما فيها رسائل الرحلات**. إذا كان المستخدم في رحلة نشطة ورسائلها غير مقروءة، ستُحذف علامة "غير مقروء" عنها أيضًا.

**الإصلاح:**
```dart
Future<void> _markAsRead(String senderId, {String? tripId}) async {
  final query = SupabaseService.client
      .from('messages')
      .update({'is_read': true})
      .eq('sender_id', senderId)
      .eq('receiver_id', userId)
      .eq('is_read', false);
  
  if (tripId != null) {
    await query.eq('trip_id', tripId);
  } else {
    await query.isFilter('trip_id', null);  // فقط الرسائل المباشرة
  }
}
```

---

### 🟡 HIDDEN-6 — `cleanup_stale_user_presence` غير مُستدعى من التطبيق

```
cleanup_stale_user_presence: EXECUTE granted to service_role only
```

الدالة موجودة لكن لا يوجد pg_cron أو Supabase Scheduled Function تستدعيها. قاعدة البيانات قد تتراكم فيها سجلات presence قديمة لمستخدمين غادروا التطبيق قبل شهر.

---

### 🟡 HIDDEN-7 — `messages.is_read` لا يُحدَّث للرسائل اللي جاية بـ Realtime

عندما يأتي رسالة جديدة عبر Realtime stream وتُضاف للـ UI، الكود لا يُنفِّذ `_markAsRead`. يُنفَّذ فقط عند `loadDirectMessages`. لو المستخدم موجود في المحادثة وجاءته رسالة جديدة عبر realtime، تبقى `is_read=false` في الداتابيز.

---

### 🟡 HIDDEN-8 — `done_all` يُعرض لكل الرسائل المُرسَلة بغض النظر عن القراءة

```dart
// في _ChatBubble
Icon(
  isSending ? Icons.access_time : Icons.done_all,
  // done_all (✓✓ أزرق) يعني "تم القراءة"
  // لكنه يظهر فور نجاح الإرسال حتى لو is_read = false
)
```

**التصميم الصحيح:**
- `access_time` → جاري الإرسال
- `done` (✓ واحدة) → تم الإرسال (is_read = false)
- `done_all` (✓✓) → تم القراءة (is_read = true)

---

## §7 تحليل مقارن بين الشاشات

| المعيار | `MessagesScreen` | `ChatbotScreen` | `ComplaintsScreen` | `NotificationsScreen` |
|---------|-----------------|-----------------|-------------------|----------------------|
| State Management | `setState` مباشر | `setState` مباشر | `StreamBuilder` | `setState` مباشر |
| Realtime | ✅ `.stream()` | ❌ لا يوجد | ✅ `.stream()` | ❌ لا يوجد |
| Pagination | ❌ | ❌ | ❌ | ❌ |
| TextInputAction.send | ✅ | ❌ | — | — |
| Error Handling | ✅ retry button | ⚠️ جزئي | ❌ فقط generic error | ⚠️ جزئي |
| Loading State | ✅ | ✅ | ✅ | ✅ |
| Empty State | ✅ | ✅ | ❌ | ❌ |
| Haptic Feedback | ✅ | ❌ | ❌ | ❌ |
| Optimistic UI | ✅ | ❌ | ❌ | ❌ |
| Deep Link Support | ❌ | — | — | ❌ |
| Navigation on FCM tap | ❌ | — | — | ❌ |

**الملاحظة الكبيرة:** `MessagesScreen` أكثر تطورًا من باقي الشاشات، لكن `ChatbotScreen` و `NotificationsScreen` يفتقران لمعايير أساسية.

---

## §8 خطة الإصلاح الكاملة

### 🚨 Phase 0 — إصلاحات قبل الـ Launch (أسبوع واحد)

```sql
-- Migration 1: إصلاح complaints.trip_id
ALTER TABLE public.complaints ALTER COLUMN trip_id DROP NOT NULL;

-- Migration 2: indexes مفقودة
CREATE INDEX idx_messages_direct_chat 
  ON public.messages (sender_id, receiver_id, created_at ASC)
  WHERE trip_id IS NULL;

CREATE INDEX idx_messages_sender 
  ON public.messages (sender_id, created_at DESC);

CREATE INDEX idx_messages_receiver
  ON public.messages (receiver_id, created_at DESC);

CREATE INDEX idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);

-- Migration 3: حذف indexes غير مستخدمة
DROP INDEX IF EXISTS public.idx_messages_trip_created;

-- Migration 4: تفعيل Realtime على support_messages
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;

-- Migration 5: تأمين anon role
REVOKE ALL ON public.messages FROM anon;
REVOKE ALL ON public.notifications FROM anon;
REVOKE ALL ON public.support_messages FROM anon;
GRANT SELECT, INSERT, UPDATE ON public.messages TO anon; -- إذا لزم

-- Migration 6: إصلاح user_presence privacy
DROP POLICY IF EXISTS "Anyone can read presence" ON public.user_presence;
CREATE POLICY "Authenticated can read presence"
  ON public.user_presence FOR SELECT TO authenticated USING (true);
```

```dart
// Flutter Fix 1: FCM deep link لـ new_message
Future<void> _handleMessageOpen(RemoteMessage message) async {
  final type = message.data['type'];
  if (type == 'new_message') {
    final senderId = message.data['senderId'];
    final tripId = message.data['tripId'];
    // navigate accordingly
  }
}

// Flutter Fix 2: complaints with nullable trip_id handling
// → complaints_repository.dart يحتاج nullable trip_id يشتغل صح

// Flutter Fix 3: TextInputAction.send في chatbot_screen.dart

// Flutter Fix 4: حذف text إنجليزي hard-coded من messages_screen.dart
```

---

### 📋 Phase 1 — الإصلاحات الأساسية (2-3 أسابيع)

| # | المشكلة | الأولوية |
|---|---------|---------|
| 1 | إصلاح `subscribeToDirectMessages` (channel بدلاً من stream) | 🔴 |
| 2 | إصلاح `_markAsRead` بفلتر `trip_id` | 🔴 |
| 3 | نقل AI calls لـ Edge Function (تأمين API Key) | 🔴 |
| 4 | إصلاح `getUnreadCountStream` باستخدام RPC | 🔴 |
| 5 | إصلاح `_markAsRead` ليُحدَّث عند وصول Realtime | 🟠 |
| 6 | إضافة navigation في `NotificationsScreen` لـ new_message | 🟠 |
| 7 | إصلاح AI conversation history (إرسال context كامل) | 🟠 |
| 8 | إصلاح `_markAsRead` لا ينتظر | 🟠 |
| 9 | إضافة pagination لـ `loadConversations` و `loadMessages` | 🟠 |
| 10 | إصلاح double notification (FCM + DB) | 🟠 |

---

### 🎨 Phase 2 — تحسينات UX (شهر)

| # | التحسين |
|---|---------|
| 11 | ربط Online Status بـ `user_presence.last_seen` |
| 12 | عرض Avatar الحقيقي بدل الأيقونة الثابتة |
| 13 | إضافة `unread_count` رقمي في قائمة المحادثات |
| 14 | إضافة badge للرسائل في الـ Drawer |
| 15 | فواصل التاريخ في المحادثة |
| 16 | زر Scroll-to-bottom |
| 17 | Read Receipts حقيقية (✓ vs ✓✓) |
| 18 | إضافة Rate Limiting على الرسائل |

---

### 🏗️ Phase 3 — إعادة هيكلة (شهرين)

| # | التحسين |
|---|---------|
| 19 | BLoC لإدارة حالة الرسائل |
| 20 | استخراج Widgets منفصلة |
| 21 | Typing Indicator عبر Supabase Presence |
| 22 | جدولة `cleanup_stale_user_presence` بـ pg_cron |
| 23 | تفعيل `REPLICA IDENTITY FULL` على `drivers_profile` للـ Realtime |

---

## ملخص تنفيذي

### الخلاصة الرقمية

| التصنيف | العدد |
|---------|-------|
| 🔴 Bugs حرجة تؤثر على الوظيفة | 6 |
| 🔴 مشاكل أمان حرجة | 5 |
| 🟠 مشاكل متوسطة (أداء + UX) | 12 |
| 🟡 تحسينات مخفية | 8 |
| ❌ Indexes مفقودة | 4 |
| ❌ Indexes غير مستخدمة (overhead) | 7+ |

### أهم 3 مشاكل يجب حلها اليوم

1. **`complaints.trip_id NOT NULL` مع كود يبعت NULL** → Crash في الإنتاج فوري
2. **FCM `new_message` tap لا يفعل شيئًا** → المستخدم لا يصل للرسائل من الإشعار
3. **Missing indexes على `messages` و `notifications`** → قاعدة البيانات ستُعاني مع الأولى 1000 مستخدم

---

*تحليل شامل لـ 304 ملف Dart + 939 صف Schema CSV | الإصدار v2.0*
