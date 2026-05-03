# دليل تنفيذ Overlay نافذة قبول/رفض الرحلة للسائق
## `system_alert_window: ^2.0.8` | Flutter + Firebase Messaging + Supabase

> **الهدف:** عندما يصل للسائق FCM Push Notification بوجود رحلة متاحة، بدلاً من الإشعار العادي الذي يظهر في شريط الإشعارات، تظهر نافذة Overlay فوق كل التطبيقات (حتى لو الموبايل على شاشة تانية) بها تفاصيل الرحلة وزرين: ✅ قبول ❌ رفض — وكل ده يتم بـ `system_alert_window: ^2.0.8`.

---

## 1. تحليل المشروع الحالي (Snapix Driver App)

### Stack التقني الموجود:
| الجزء | الباكدج |
|---|---|
| State Management | `flutter_bloc ^8.1.0` |
| Routing | `go_router ^14.2.7` |
| Backend | `supabase_flutter ^2.5.0` |
| Push Notifications | `firebase_messaging ^15.1.3` |
| Local Notifications | `flutter_local_notifications ^17.2.2` |
| Background Service | `flutter_background_service ^5.0.5` |
| Maps | `google_maps_flutter ^2.9.0` |

### ملاحظات مهمة من `pubspec.yaml`:
- اسم التطبيق: `snapix`
- الـ package name المتوقع: `com.snapix.driver` أو مشابه (يجب التحقق من `android/app/build.gradle`)
- يستخدم بالفعل `firebase_messaging` و `flutter_local_notifications` — الكود الجديد يجب أن يتكامل معهم وليس يستبدلهم
- يستخدم `flutter_background_service` — الـ Overlay سيعمل معه بدون conflict

---

## 2. المبدأ الكامل لكيفية عمل الـ Overlay

```
[Supabase / Server]
       ↓  يرسل FCM Data-Only Message
[Firebase Cloud Messaging]
       ↓
[FirebaseMessaging.onBackgroundMessage]  ← يشتغل حتى لو App مغلق
       ↓
[نفذ SystemAlertWindow.showSystemWindow()]
       ↓
[Android يفتح Flutter Engine منفصل على overlayMain()]
       ↓
[RideOfferOverlay Widget] يظهر فوق كل التطبيقات
       ↓
[السائق يضغط قبول أو رفض]
       ↓
[IsolateNameServer يرسل النتيجة للـ Main App]
       ↓
[Main App يرسل الرد لـ Supabase]
```

---

## 3. الخطوة الأولى: إضافة الـ Dependency

### في `pubspec.yaml` — أضف السطر ده تحت `dependencies:`

```yaml
dependencies:
  # ... الباكدجات الموجودة ...
  
  # Overlay Window
  system_alert_window: ^2.0.8
```

ثم شغّل:
```bash
flutter pub get
```

---

## 4. الخطوة الثانية: تعديل `AndroidManifest.xml`

### المسار: `android/app/src/main/AndroidManifest.xml`

#### أضف الـ Permissions دي قبل `<application>` مباشرة:

```xml
<!-- Permissions الموجودة مسبقاً في المشروع -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>

<!-- ✅ جديد: Permissions الـ Overlay -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

#### داخل `<application>`:

أضف الـ `android:name` للـ Application Class (شوف الخطوة 5 الأول):

```xml
<application
    android:name=".Application"
    android:label="snapix"
    android:icon="@mipmap/ic_launcher"
    android:enableOnBackInvokedCallback="true">
    
    <!-- MainActivity الموجودة -->
    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:launchMode="singleTop"
        android:theme="@style/LaunchTheme">
        <!-- ... محتوى الـ activity الموجود ... -->
    </activity>
    
    <!-- ✅ جديد: Service الـ Overlay -->
    <!-- هذا الـ Service يشغّل الـ Flutter Engine الخاص بالـ Overlay -->
    <!-- لا تغير اسمه لأنه داخلي في الباكدج -->
    
</application>
```

> **⚠️ ملاحظة مهمة:** الباكدج `system_alert_window 2.0.8` يسجّل الـ Service تلقائياً عبر Gradle manifest merging. **لا تضيف** `<service>` يدوياً إلا لو الـ build أعطاك error يقول إنه مش موجود.

---

## 5. الخطوة الثالثة: إنشاء `Application.kt`

### المسار: `android/app/src/main/kotlin/[package_name]/Application.kt`

> **افتح** `android/app/build.gradle` وشوف الـ `applicationId` عشان تعرف الـ package name الصح. مثلاً لو كان `com.snapix.driver` يبقى المسار: `android/app/src/main/kotlin/com/snapix/driver/Application.kt`

```kotlin
package com.snapix.driver   // ← غيّر ده للـ package name بتاعك

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugins.GeneratedPluginRegistrant

class Application : FlutterApplication(), PluginRegistry.PluginRegistrantCallback {
    override fun onCreate() {
        super.onCreate()
        // ✅ مطلوب عشان الـ click events تشتغل في الـ background
        // لما التطبيق يكون مغلق والـ overlay شاغل
        com.jvapps.system_alert_window.SystemAlertWindowPlugin.setPluginRegistrant(this)
    }

    override fun registerWith(registry: PluginRegistry) {
        GeneratedPluginRegistrant.registerWith(registry)
    }
}
```

---

## 6. الخطوة الرابعة: تعديل `main.dart`

### المسار: `lib/main.dart`

#### الملف الحالي (الهيكل المتوقع):
```dart
// الكود الحالي المتوقع في main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // ... إعدادات أخرى ...
  runApp(const MyApp());
}
```

#### ✅ الكود الجديد الكامل لـ `main.dart` بعد التعديل:

```dart
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:system_alert_window/system_alert_window.dart';

// ✅ Import الـ Overlay Widget الجديد (سننشئه في الخطوة 7)
import 'features/ride_offer/presentation/overlay/ride_offer_overlay.dart';

// ✅ Import الـ IsolateManager الجديد (سننشئه في الخطوة 8)
import 'core/overlay/isolate_manager.dart';

// ============================================================
// 🔴 BACKGROUND FCM HANDLER
// يجب أن يكون على مستوى الـ top-level (خارج أي class)
// يشتغل حتى لو التطبيق مغلق تماماً
// ============================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // تحقق إن الرسالة دي offer رحلة
  if (message.data['type'] == 'ride_offer') {
    await _showRideOfferOverlay(message.data);
  }
}

// ============================================================
// ✅ OVERLAY ENTRY POINT
// يجب أن يكون على مستوى الـ top-level
// Flutter يستخدمه كـ entry point منفصل لتشغيل الـ Overlay Widget
// ============================================================
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RideOfferOverlay(), // ← الـ Widget الخاص بالـ Overlay
    ),
  );
}

// ============================================================
// دالة مساعدة لإظهار الـ Overlay
// ============================================================
Future<void> _showRideOfferOverlay(Map<String, dynamic> rideData) async {
  // 1. تحقق من الصلاحية أولاً
  bool? hasPermission = await SystemAlertWindow.checkPermissions(
    prefMode: SystemWindowPrefMode.OVERLAY,
  );
  
  if (hasPermission != true) {
    // لو مفيش صلاحية، اطلبها (ده هيفتح إعدادات الجهاز)
    await SystemAlertWindow.requestPermissions(
      prefMode: SystemWindowPrefMode.OVERLAY,
    );
    return;
  }

  // 2. ابعت بيانات الرحلة للـ Overlay قبل ما تفتحه
  await SystemAlertWindow.sendMessageToOverlay(
    _encodeRideData(rideData),
  );

  // 3. افتح الـ Overlay
  await SystemAlertWindow.showSystemWindow(
    height: 280,                              // ارتفاع الـ Overlay بالـ pixels
    width: 500,                               // عرض الـ Overlay (أو اترك default للـ MATCH_PARENT)
    gravity: SystemWindowGravity.TOP,         // يظهر من فوق الشاشة
    notificationTitle: "🚖 رحلة جديدة!",    // عنوان الـ bubble notification (Android 11+)
    notificationBody: "اضغط لرؤية التفاصيل",
    prefMode: SystemWindowPrefMode.OVERLAY,   // يجبر على الـ Overlay حتى في Android 11+
  );
}

// تحويل بيانات الرحلة لـ String عشان نبعتها للـ Overlay
String _encodeRideData(Map<String, dynamic> data) {
  return [
    data['ride_id'] ?? '',
    data['pickup_address'] ?? '',
    data['dropoff_address'] ?? '',
    data['fare'] ?? '0',
    data['distance'] ?? '0',
    data['passenger_name'] ?? '',
    data['passenger_rating'] ?? '5.0',
  ].join('|||'); // separator واضح ومش موجود في الـ data
}

// ============================================================
// MAIN FUNCTION
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // ✅ سجّل الـ background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ سجّل IsolatePort عشان نستقبل ردود الـ Overlay في الـ Main App
  _setupOverlayCallbackPort();

  // ... باقي الإعدادات الموجودة (Supabase, etc.) ...

  runApp(const MyApp());
}

// ============================================================
// إعداد استقبال ردود الـ Overlay في الـ Main App
// ============================================================
void _setupOverlayCallbackPort() {
  final receivePort = ReceivePort();
  IsolateManager.registerPortWithName(receivePort.sendPort);

  receivePort.listen((message) {
    // message هيكون "accept:RIDE_ID" أو "reject:RIDE_ID"
    if (message is String) {
      final parts = message.split(':');
      if (parts.length == 2) {
        final action = parts[0]; // "accept" أو "reject"
        final rideId = parts[1];

        if (action == 'accept') {
          _handleRideAccept(rideId);
        } else if (action == 'reject') {
          _handleRideReject(rideId);
        }
      }
    }
  });
}

// ✅ عند قبول الرحلة
Future<void> _handleRideAccept(String rideId) async {
  // هنا تبعت الـ accept لـ Supabase
  // مثال:
  // await SupabaseClient.from('rides').update({'status': 'accepted', 'driver_id': currentDriverId}).eq('id', rideId);
  
  // ثم افتح صفحة الرحلة في التطبيق
  // navigatorKey.currentState?.pushNamed('/ride-details', arguments: rideId);
  
  print('✅ Driver accepted ride: $rideId');
}

// ❌ عند رفض الرحلة
Future<void> _handleRideReject(String rideId) async {
  // هنا تبعت الـ reject لـ Supabase
  // مثال:
  // await SupabaseClient.from('rides').update({'status': 'rejected'}).eq('id', rideId);
  
  print('❌ Driver rejected ride: $rideId');
}
```

---

## 7. الخطوة الخامسة: إنشاء `RideOfferOverlay` Widget

### المسار: `lib/features/ride_offer/presentation/overlay/ride_offer_overlay.dart`

> **⚠️ مهم جداً:** هذا الـ Widget يشتغل في **Flutter Engine منفصل تماماً**. لا يمكنه الوصول لأي BLoC أو Provider أو State Management موجود في التطبيق الأساسي. يجب أن يكون **Self-contained**.

```dart
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:system_alert_window/system_alert_window.dart';

// ✅ Import IsolateManager (سنستخدمه لإرسال النتيجة للـ Main App)
import '../../../../core/overlay/isolate_manager.dart';

// ============================================================
// RideOfferOverlay
// النافذة التي تظهر فوق كل التطبيقات عند وجود رحلة جديدة
// ============================================================
class RideOfferOverlay extends StatefulWidget {
  const RideOfferOverlay({super.key});

  @override
  State<RideOfferOverlay> createState() => _RideOfferOverlayState();
}

class _RideOfferOverlayState extends State<RideOfferOverlay> {
  // بيانات الرحلة
  String rideId = '';
  String pickupAddress = '';
  String dropoffAddress = '';
  String fare = '0';
  String distance = '0';
  String passengerName = '';
  String passengerRating = '5.0';

  // مؤقت العد التنازلي (30 ثانية للقبول أو الرفض)
  int _countdown = 30;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // ✅ استمع للبيانات القادمة من الـ Main App
    SystemAlertWindow.overlayListener.listen((event) {
      if (event != null && event is String) {
        _parseRideData(event);
      }
    });

    // ابدأ العد التنازلي
    _startCountdown();
  }

  // تحليل البيانات المستقبلة من الـ Main App
  void _parseRideData(String encoded) {
    final parts = encoded.split('|||');
    if (parts.length >= 7) {
      setState(() {
        rideId = parts[0];
        pickupAddress = parts[1];
        dropoffAddress = parts[2];
        fare = parts[3];
        distance = parts[4];
        passengerName = parts[5];
        passengerRating = parts[6];
      });
    }
  }

  // العد التنازلي — لو انتهى بدون رد يُعتبر رفض تلقائي
  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _onReject(); // رفض تلقائي
        return false;
      }
      return true;
    });
  }

  // ✅ عند الضغط على "قبول"
  void _onAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // أرسل النتيجة للـ Main App عبر IsolateNameServer
    final port = IsolateManager.lookupPortByName();
    port?.send('accept:$rideId');

    // أغلق الـ Overlay
    await SystemAlertWindow.closeSystemWindow(
      prefMode: SystemWindowPrefMode.OVERLAY,
    );
  }

  // ❌ عند الضغط على "رفض" أو انتهاء الوقت
  void _onReject() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // أرسل النتيجة للـ Main App
    final port = IsolateManager.lookupPortByName();
    port?.send('reject:$rideId');

    // أغلق الـ Overlay
    await SystemAlertWindow.closeSystemWindow(
      prefMode: SystemWindowPrefMode.OVERLAY,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),   // لون خلفية داكن يشبه ثيم التطبيق
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Header ───
              _buildHeader(),
              const Divider(color: Colors.white24, height: 1),

              // ─── Ride Details ───
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAddressRow(
                      icon: Icons.radio_button_checked,
                      iconColor: Colors.green,
                      label: 'نقطة الانطلاق',
                      value: pickupAddress.isEmpty ? 'جارٍ التحميل...' : pickupAddress,
                    ),
                    const SizedBox(height: 8),
                    _buildAddressRow(
                      icon: Icons.location_on,
                      iconColor: Colors.red,
                      label: 'الوجهة',
                      value: dropoffAddress.isEmpty ? 'جارٍ التحميل...' : dropoffAddress,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoChip('💰 ${fare} ج.م', Colors.amber),
                        _buildInfoChip('📍 ${distance} كم', Colors.blue),
                        _buildInfoChip('⏱ ${_countdown}ث', _countdown <= 10 ? Colors.red : Colors.white54),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── Action Buttons ───
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    // زر الرفض
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _onReject,
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text(
                          'رفض',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // زر القبول
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _onAccept,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'قبول',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43A047),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper Widgets ───

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_taxi, color: Colors.amber, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'طلب رحلة جديدة! 🚖',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (passengerName.isNotEmpty)
                  Text(
                    'الراكب: $passengerName ⭐ $passengerRating',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
              ],
            ),
          ),
          // Countdown Circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _countdown <= 10 ? Colors.red : Colors.white24,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '$_countdown',
                style: TextStyle(
                  color: _countdown <= 10 ? Colors.red : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
```

---

## 8. الخطوة السادسة: إنشاء `IsolateManager`

### المسار: `lib/core/overlay/isolate_manager.dart`

> هذا الملف ضروري لأن الـ Overlay يشتغل في **Isolate منفصل** ولا يمكنه التواصل مع الـ Main App مباشرة. الحل هو `IsolateNameServer` من Dart.

```dart
import 'dart:isolate';
import 'dart:ui';

/// يدير التواصل بين الـ Overlay Isolate والـ Main App Isolate
/// عبر IsolateNameServer المدمج في Dart
class IsolateManager {
  // الاسم المسجّل للـ Port في الـ IsolateNameServer
  // يجب أن يكون نفس الاسم في الطرفين (Main App + Overlay)
  static const String _portName = 'snapix_overlay_port';

  /// يسجّل الـ Main App Port عشان يستقبل رسائل من الـ Overlay
  /// يُستدعى مرة واحدة في main()
  static bool registerPortWithName(SendPort port) {
    // احذف القديم لو موجود عشان نتجنب conflict
    removePortNameMapping(_portName);
    return IsolateNameServer.registerPortWithName(port, _portName);
  }

  /// الـ Overlay يستخدم ده عشان يبعت رسائل للـ Main App
  /// ممكن يرجع null لو الـ Main App مش شاغل (app مغلق تماماً)
  static SendPort? lookupPortByName() {
    return IsolateNameServer.lookupPortByName(_portName);
  }

  /// إزالة تسجيل الـ Port (عند إغلاق التطبيق)
  static bool removePortNameMapping(String name) {
    return IsolateNameServer.removePortNameMapping(name);
  }
}
```

---

## 9. الخطوة السابعة: طلب الصلاحية من المستخدم (عند أول تشغيل)

### المسار: في الـ Screen الخاص بتسجيل دخول السائق أو الـ HomeScreen

أضف الكود ده في `initState` أو `onDriverOnline` (عند ما يبدأ السائق نوبته):

```dart
import 'package:system_alert_window/system_alert_window.dart';

// في أي Widget/Screen مناسب
Future<void> _requestOverlayPermission() async {
  // تحقق أولاً
  bool? hasPermission = await SystemAlertWindow.checkPermissions(
    prefMode: SystemWindowPrefMode.OVERLAY,
  );

  if (hasPermission != true) {
    // اشرح للسائق ليه محتاج الصلاحية
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصريح مطلوب'),
        content: const Text(
          'عشان تستقبل طلبات الرحلة حتى لما التطبيق في الخلفية، '
          'نحتاج إذنك لعرض النوافذ فوق التطبيقات الأخرى.\n\n'
          'في الشاشة التالية ابحث عن "Snapix" وفعّل الإذن.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ليس الآن'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('موافق'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      await SystemAlertWindow.requestPermissions(
        prefMode: SystemWindowPrefMode.OVERLAY,
      );
    }
  }
}
```

---

## 10. الخطوة الثامنة: التكامل مع FCM Foreground (لما التطبيق شاغل)

### المسار: أي ملف عنده `FirebaseMessaging.onMessage` (غالباً في `notification_service.dart` أو `main.dart`)

```dart
// استمع للرسائل لما التطبيق في الـ Foreground
FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
  // لو رسالة عرض رحلة
  if (message.data['type'] == 'ride_offer') {
    // استخدم نفس دالة الـ Overlay (مش الـ Flutter Local Notification العادية)
    await _showRideOfferOverlay(message.data);
  } else {
    // باقي أنواع الإشعارات تشتغل بالطريقة العادية (flutter_local_notifications)
    // ... الكود الموجود حالياً ...
  }
});
```

---

## 11. هيكل الـ FCM Message المطلوب من السيرفر

### الـ Payload الذي يجب أن يُرسله السيرفر / Supabase Edge Function:

```json
{
  "to": "DRIVER_FCM_TOKEN",
  "priority": "high",
  "data": {
    "type": "ride_offer",
    "ride_id": "uuid-of-the-ride",
    "pickup_address": "شارع التحرير، القاهرة",
    "dropoff_address": "مطار القاهرة الدولي",
    "fare": "85",
    "distance": "18.5",
    "passenger_name": "محمد أحمد",
    "passenger_rating": "4.8",
    "pickup_lat": "30.0444",
    "pickup_lng": "31.2357",
    "dropoff_lat": "30.1218",
    "dropoff_lng": "31.4056"
  }
}
```

> **⚠️ مهم جداً:** استخدم `data`-only message (مش `notification` + `data`). لأن الـ `notification` messages على Android تُعرض تلقائياً بواسطة النظام وبتتجاوز الـ `onBackgroundMessage` handler — بالتالي الـ Overlay مش هيظهر.

### في Supabase Edge Function:

```typescript
// supabase/functions/send-ride-offer/index.ts
const response = await fetch('https://fcm.googleapis.com/fcm/send', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `key=${FCM_SERVER_KEY}`,
  },
  body: JSON.stringify({
    to: driverFcmToken,
    priority: 'high',
    data: {  // ← data فقط، بدون notification
      type: 'ride_offer',
      ride_id: ride.id,
      pickup_address: ride.pickup_address,
      dropoff_address: ride.dropoff_address,
      fare: ride.fare.toString(),
      distance: ride.distance.toString(),
      passenger_name: passenger.name,
      passenger_rating: passenger.rating.toString(),
    },
  }),
});
```

---

## 12. هيكل الملفات الجديدة الكاملة

```
lib/
├── main.dart                          ← تعديل (إضافة overlayMain + FCM handler)
│
├── core/
│   └── overlay/
│       └── isolate_manager.dart       ← جديد ✅
│
└── features/
    └── ride_offer/
        └── presentation/
            └── overlay/
                └── ride_offer_overlay.dart   ← جديد ✅

android/
├── app/
│   └── src/
│       └── main/
│           ├── AndroidManifest.xml    ← تعديل (إضافة permissions)
│           └── kotlin/
│               └── [package]/
│                   ├── MainActivity.kt   ← موجود (لا تغيير)
│                   └── Application.kt    ← جديد ✅
```

---

## 13. ملاحظات حرجة وحالات الـ Edge Cases

### 🔴 Android Versions:

| الإصدار | السلوك |
|---|---|
| Android 8-10 | يظهر كـ Window فوق كل التطبيقات مباشرة ✅ |
| Android 11+ | يظهر كـ Window مع `prefMode: OVERLAY` ✅ |
| Android GO (API 27) | يظهر كـ Window ✅ |
| Android GO (API 29) | يظهر كـ Bubble (المستخدم يفتحه) |

### 🔴 حالة: التطبيق مغلق تماماً (Terminated):
- الـ `onBackgroundMessage` يشتغل في Isolate منفصل عن الـ Main App
- الـ `IsolateManager.lookupPortByName()` سيرجع `null` لأن الـ Main App مش شاغل
- **الحل:** لو رجع `null`، ابعت الرد مباشرة لـ Supabase من داخل الـ Overlay نفسه عبر `http` package

```dart
// في ride_offer_overlay.dart — عند القبول لو التطبيق مغلق
void _onAccept() async {
  final port = IsolateManager.lookupPortByName();
  
  if (port != null) {
    // التطبيق شاغل — ابعت للـ Main App
    port.send('accept:$rideId');
  } else {
    // التطبيق مغلق — ابعت مباشرة لـ Supabase
    await _sendDirectToSupabase('accepted', rideId);
  }
  
  await SystemAlertWindow.closeSystemWindow(
    prefMode: SystemWindowPrefMode.OVERLAY,
  );
}

Future<void> _sendDirectToSupabase(String status, String rideId) async {
  // استخدم http package مباشرة (مش Supabase Flutter SDK لأنه محتاج initialize)
  // ملاحظة: الـ Overlay Isolate يعتبر بيئة منفصلة تماماً
  try {
    final response = await http.patch(
      Uri.parse('https://YOUR_SUPABASE_URL/rest/v1/rides?id=eq.$rideId'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': 'YOUR_SUPABASE_ANON_KEY',
        'Authorization': 'Bearer YOUR_SUPABASE_ANON_KEY',
      },
      body: jsonEncode({'status': status}),
    );
    print('Supabase response: ${response.statusCode}');
  } catch (e) {
    print('Error sending to Supabase: $e');
  }
}
```

> **لهذه الحالة:** أضف `http: ^1.2.2` في imports الـ `ride_offer_overlay.dart` — وهو موجود بالفعل في الـ `pubspec.yaml`!

### 🔴 مشكلة الـ Fonts / Theme في الـ Overlay:
الـ Overlay Widget يشتغل في Engine منفصل. لو حاولت تستخدم `google_fonts` أو أي Custom Font من الـ `pubspec.yaml` قد يفشل لأن الـ assets مش محملة. الحل:
```dart
// في overlayMain() — اضبط الـ theme بدون google fonts
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: null, // استخدم الـ system font
      ),
      home: const RideOfferOverlay(),
    ),
  );
}
```

### 🔴 مشكلة الـ `flutter_background_service` مع `system_alert_window`:
الاثنين يستخدموا Isolates منفصلة — لا يوجد conflict. لكن تأكد إن الـ `Application.kt` مسجّل بشكل صحيح عشان كلهم يشتغلوا معاً.

### 🔴 الـ Overlay لا يظهر لو permissions مش ممنوحة:
- طلب الصلاحية **يجب** أن يتم وهو التطبيق في الـ Foreground
- مش ممكن تطلبها من الـ Background Handler
- لذلك اطلبها في الـ onboarding أو عند الضغط على "أنا متاح" (online)

---

## 14. قائمة التحقق النهائية (Checklist)

```
□ تمت إضافة system_alert_window: ^2.0.8 في pubspec.yaml
□ flutter pub get شغّال بدون أخطاء
□ تمت إضافة SYSTEM_ALERT_WINDOW permission في AndroidManifest.xml
□ تمت إضافة FOREGROUND_SERVICE permission في AndroidManifest.xml
□ تمت إضافة WAKE_LOCK permission في AndroidManifest.xml
□ تمت إضافة android:name=".Application" في <application> tag
□ تم إنشاء Application.kt بالـ package name الصحيح
□ تم إنشاء overlayMain() بـ @pragma('vm:entry-point') في main.dart
□ تم إنشاء RideOfferOverlay Widget
□ تم إنشاء IsolateManager
□ تم تعديل _firebaseMessagingBackgroundHandler
□ تم تعديل FirebaseMessaging.onMessage.listen
□ تم إضافة طلب الصلاحية في الـ UI
□ الـ FCM message من السيرفر هو data-only (بدون notification key)
□ تم اختبار الـ Overlay على Android 10
□ تم اختبار الـ Overlay على Android 12+
□ تم اختبار الحالة: التطبيق مغلق تماماً
□ تم اختبار الحالة: التطبيق في الـ Background
□ تم اختبار الحالة: التطبيق في الـ Foreground
□ تم اختبار انتهاء الـ 30 ثانية (رفض تلقائي)
```

---

## 15. أوامر التشغيل والـ Build

```bash
# تنظيف وإعادة البناء (مطلوب بعد تغييرات الـ Android)
flutter clean
flutter pub get
flutter run

# للـ Release Build
flutter build apk --release
# أو
flutter build appbundle --release
```

---

## ملخص تسلسل التنفيذ للـ AI

```
1. افتح pubspec.yaml → أضف system_alert_window: ^2.0.8
2. افتح android/app/src/main/AndroidManifest.xml → أضف 3 permissions + android:name=".Application"
3. اقرأ applicationId من android/app/build.gradle → استخدمه في Application.kt
4. أنشئ android/app/src/main/kotlin/[PACKAGE_PATH]/Application.kt
5. أنشئ lib/core/overlay/isolate_manager.dart
6. أنشئ lib/features/ride_offer/presentation/overlay/ride_offer_overlay.dart
7. عدّل lib/main.dart (أضف overlayMain + عدّل background handler)
8. ابحث عن أي ملف فيه FirebaseMessaging.onMessage.listen → أضف إليه الـ overlay call
9. ابحث عن الـ screen الخاص بالـ driver online/login → أضف طلب الصلاحية
10. شغّل flutter clean && flutter pub get && flutter run
```
