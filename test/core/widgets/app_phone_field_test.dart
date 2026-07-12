// ════════════════════════════════════════════════════════════════════════
// اختبار وحدة (Unit/Widget Test) لـ AppPhoneField
// ════════════════════════════════════════════════════════════════════════
// مطلب 12 من MASTER_PLAN.md — يغطي الحالات الثلاث المطلوبة صراحة:
//   1) رقم جديد عادي (initialFullNumber == null) — سياق الإنشاء الحالي.
//   2) بناء الرقم الكامل بشكل صحيح مع الدولة الافتراضية (يغطي مسار
//      _fireChange بعد أن يحدد المستخدم دولة ويكتب رقمًا محليًا).
//   3) تمرير initialFullNumber — التأكد من فصل dialCode عن الرقم المحلي
//      بشكل صحيح وعدم حدوث تكرار (تكرار حرفي مثل "+20+201001234567")
//      عند إعادة تمرير القيمة الناتجة من onChanged كـ initialFullNumber
//      من جديد (محاكاة تحميل بيانات محفوظة في شاشة التعديل).
//
// ملاحظة بنيوية: هذا المشروع لا يحتوي على مجلد test/ سابقًا — كل الاختبارات
// الموجودة integration_test/ فقط (E2E حقيقية على Supabase). هذا الملف هو
// أول unit/widget test في المشروع، ويستخدم حزمة flutter_test الموجودة
// أصلاً في dev_dependencies (pubspec.yaml) دون أي إضافة جديدة.
// ════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/widgets/app_phone_field.dart';

/// يلف AppPhoneField بـ MaterialApp + AppLocalizations delegates الحقيقية —
/// نفس الإعداد المستخدم فعليًا في main.dart (سطر 204-206) — لأن الـ widget
/// يعتمد على AppLocalizations.of(context)! داخليًا (label، hint، رسائل
/// الخطأ)، وبدون هذا الإعداد سيفشل الاختبار بـ null exception.
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Material(child: child)),
  );
}

void main() {
  group('AppPhoneField — بناء الرقم في سياق الإنشاء (initialFullNumber = null)',
      () {
    testWidgets('الحقل يبدأ فارغًا بدون أي رقم ابتدائي، بالدولة الافتراضية EG',
        (tester) async {
      String? emitted;
      await tester.pumpWidget(_wrap(AppPhoneField(
        onChanged: (number) => emitted = number,
      )));

      // لا استدعاء لـ onChanged عند البناء الأولي — initialFullNumber فارغ
      // (null الافتراضي)، و_applyInitialFullNumber تُرجع مبكرًا دون فعل شيء
      // ودون استدعاء widget.onChanged (موثّق صراحة في الكود: القيمة الابتدائية
      // مسؤولية الشاشة الأب وليست AppPhoneField نفسها).
      expect(emitted, isNull);

      // كود الدولة الافتراضي (EG) يظهر في الـ prefix.
      expect(find.text('EG'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);

      // حقل الإدخال فارغ فعليًا (لا رقم مبدئي مدمج بالخطأ).
      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller!.text, isEmpty);
    });

    testWidgets('كتابة رقم محلي عادي تبني الرقم الكامل بدمج dialCode مرة واحدة فقط',
        (tester) async {
      String? emitted;
      await tester.pumpWidget(_wrap(AppPhoneField(
        onChanged: (number) => emitted = number,
      )));

      await tester.enterText(find.byType(TextFormField), '1001234567');
      await tester.pump();

      // dialCode (+20) يُدمج مرة واحدة فقط مع الرقم المحلي المُدخَل حديثًا —
      // وليس مع رقم قديم كان موجودًا بالفعل، لأن الحقل بدأ فارغًا تمامًا.
      expect(emitted, '+201001234567');
      // تأكيد سلبي: لا يوجد أي تكرار حرفي للكود الدولي داخل الناتج.
      expect(emitted, isNot(contains('+20+20')));
    });
  });

  group('AppPhoneField — سياق التعديل (initialFullNumber معبّأ)', () {
    testWidgets(
        'تمرير رقم مصري كامل يفصل +20 عن الرقم المحلي دون أي تكرار في الـ controller',
        (tester) async {
      await tester.pumpWidget(_wrap(AppPhoneField(
        onChanged: (_) {},
        initialFullNumber: '+201001234567',
      )));

      // الدولة المكتشفة تلقائيًا يجب أن تكون مصر (EG) — أُخذت من مطابقة
      // dialCode، وليست initialCountryCode الافتراضية فقط بالمصادفة
      // (سنتحقق من هذا بشكل حاسم في الاختبار التالي بدولة غير EG).
      expect(find.text('EG'), findsOneWidget);
      expect(find.text('+20'), findsOneWidget);

      // الأهم: controller الداخلي يحتوي على الرقم المحلي فقط (بدون "+20"
      // بداخله) — هذا هو جوهر الحماية من التكرار عند _fireChange() اللاحقة،
      // لأن أي "+20" متبقٍ داخل controller.text كان سيُدمج مرة ثانية.
      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller!.text, '1001234567');
      expect(textField.controller!.text, isNot(contains('+')));
    });

    testWidgets(
        'تمرير رقم سعودي كامل (+966) يكتشف الدولة الصحيحة، لا يبقى على EG الافتراضية',
        (tester) async {
      await tester.pumpWidget(_wrap(AppPhoneField(
        onChanged: (_) {},
        initialCountryCode: 'EG', // الافتراضي — يجب أن يُستبدَل فعليًا
        initialFullNumber: '+966501234567',
      )));

      expect(find.text('SA'), findsOneWidget);
      expect(find.text('+966'), findsOneWidget);
      expect(find.text('EG'), findsNothing);

      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.controller!.text, '501234567');
    });

    testWidgets(
        'محاكاة إعادة فتح شاشة التعديل: تمرير القيمة الناتجة من onChanged كـ '
        'initialFullNumber من جديد لا ينتج عنه أي تكرار في الرقم النهائي المُصدَر',
        (tester) async {
      // الخطوة 1: مستخدم جديد يكتب رقمه لأول مرة.
      String? firstEmitted;
      await tester.pumpWidget(_wrap(AppPhoneField(
        onChanged: (number) => firstEmitted = number,
      )));
      await tester.enterText(find.byType(TextFormField), '1001234567');
      await tester.pump();
      expect(firstEmitted, '+201001234567');

      // الخطوة 2: نفس القيمة المخزَّنة (firstEmitted) تُمرَّر لاحقًا كـ
      // initialFullNumber في شاشة تعديل البروفايل — هذا بالضبط سيناريو
      // driver_profile_screen.dart / user_profile_screen.dart بعد الخطوة 8.
      String? secondEmitted;
      await tester.pumpWidget(_wrap(AppPhoneField(
        key: const ValueKey('reopen'),
        onChanged: (number) => secondEmitted = number,
        initialFullNumber: firstEmitted,
      )));

      // لا استدعاء تلقائي لـ onChanged عند إعادة الفتح (القيمة الابتدائية
      // مسؤولية الشاشة الأب، ليست AppPhoneField).
      expect(secondEmitted, isNull);

      // لو عدّل المستخدم رقمًا واحدًا فقط، يجب أن يبقى dialCode مدمجًا مرة
      // واحدة بالظبط في الناتج — وليس مرتين ("+20+201001234567").
      await tester.enterText(find.byType(TextFormField), '1001234568');
      await tester.pump();
      expect(secondEmitted, '+201001234568');
      expect(secondEmitted, isNot(contains('+20+20')));
    });

    testWidgets(
        'رقم بلا كود دولة معروف (fallback آمن): لا فقدان للبيانات ولا استثناء',
        (tester) async {
      // رقم يبدأ بصيغة غير موجودة في _kCountries إطلاقًا — يجب ألا يرمي
      // الـ widget أي استثناء، ويجب أن يعرض كل الأرقام كما هي بدل تجاهلها.
      await tester.pumpWidget(_wrap(AppPhoneField(
        onChanged: (_) {},
        initialFullNumber: '+999888777666',
      )));

      // يبقى على الدولة الافتراضية (initialCountryCode الافتراضي EG) لأن
      // لا يوجد كود دولة معروف يطابق بداية الرقم.
      expect(find.text('EG'), findsOneWidget);

      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      // كل الأرقام (بدون علامة +) تظهر كما هي — لا فقدان بيانات.
      expect(textField.controller!.text, '999888777666');
    });
  });
}
