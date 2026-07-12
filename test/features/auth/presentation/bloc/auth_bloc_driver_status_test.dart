// اختبارات انتقالات حالة السائق (driver_account_status) عبر AuthBloc.
//
// يغطي هذا الملف البنود 15-16 من المرحلة د في MASTER_PLAN.md (القسم 4):
// كل الانتقالات السبعة المطلوبة صراحة + سيناريو "الجلسة المفتوحة" الحرج.
//
// اختيار منهجي: هذه اختبارات وحدة (unit) على AuthBloc مباشرة عبر AuthRepository
// مُزيَّف (fake)، وليست اختبارات تكامل (integration_test) تحتاج قاعدة بيانات حية.
// السبب: منطق تحويل account_status → AuthState بالكامل موجود في
// AuthBloc._onDriverAccountStatusChanged (auth_bloc.dart سطور 51-68)، وهذا هو
// بالضبط ما تحتاج المرحلة د التحقق من صحته. اختبار عبر قاعدة حية كان سيتطلب
// تنفيذ migration المرحلة ب أولاً (لم يُنفَّذ بعد على القاعدة الحية وقت كتابة
// هذا الملف)، وحسابات إدارية حقيقية — وهو عبء غير ضروري لاختبار منطق التحويل
// نفسه الذي يمكن عزله بالكامل عن أي اتصال شبكة.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snapix/core/models/driver_profile_model.dart';
import 'package:snapix/features/auth/domain/entities/user_entity.dart';
import 'package:snapix/features/auth/domain/repositories/auth_repository.dart';
import 'package:snapix/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:snapix/features/auth/presentation/bloc/auth_event.dart';
import 'package:snapix/features/auth/presentation/bloc/auth_state.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;

  final driver = UserEntity(
    id: 'driver-1',
    name: 'سائق تجريبي',
    phone: '01000000000',
    email: 'driver@test.com',
    role: 'driver',
    rating: 4.8,
    totalTrips: 10,
    language: 'ar',
    isActive: true,
    isBlocked: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    repository = _MockAuthRepository();
  });

  // ═══════════════════════════════════════════════════════════════════════
  // الانتقالات الستة المباشرة (DriverAccountStatusChanged → AuthState)
  // كل انتقال يُختبر بمعزل عبر seed لتفادي الاعتماد على تسلسل أحداث سابق.
  // ═══════════════════════════════════════════════════════════════════════

  group('انتقالات DriverAccountStatusChanged المباشرة', () {
    blocTest<AuthBloc, AuthState>(
      // يغطي معاً: "Pending → Approved" و"Review Required → Approved" — كلاهما
      // نفس القيمة enum بالضبط (DriverAccountStatus.pendingReview) ونفس حالة
      // AuthState (AuthDriverPending)، بلا تفريق سلوكي بينهما، كما نصّت
      // MASTER_PLAN.md القسم 6 بند 5 صراحة أن هذا مقصود وليس نقصاً.
      'pendingReview → approved (يغطي Pending→Approved وReview Required→Approved)',
      build: () => AuthBloc(repository),
      seed: () => AuthDriverPending(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(driver, DriverAccountStatus.approved, null),
      ),
      expect: () => [isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'approved → pendingReview بدون سبب (سحب الاعتماد)',
      build: () => AuthBloc(repository),
      seed: () => AuthAuthenticated(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(driver, DriverAccountStatus.pendingReview, null),
      ),
      expect: () => [
        isA<AuthDriverPending>().having(
          (s) => s.revisionReason,
          'revisionReason',
          isNull,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'approved → pendingReview مع سبب مراجعة (طلب مراجعة) — السبب يصل كما هو',
      build: () => AuthBloc(repository),
      seed: () => AuthAuthenticated(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(
          driver,
          DriverAccountStatus.pendingReview,
          'الرجاء رفع صورة أوضح للرخصة',
        ),
      ),
      expect: () => [
        isA<AuthDriverPending>().having(
          (s) => s.revisionReason,
          'revisionReason',
          'الرجاء رفع صورة أوضح للرخصة',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'pendingReview → blocked',
      build: () => AuthBloc(repository),
      seed: () => AuthDriverPending(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(driver, DriverAccountStatus.blocked, 'مخالفة شروط الاستخدام'),
      ),
      expect: () => [
        isA<AuthDriverBlocked>().having(
          (s) => s.reason,
          'reason',
          'مخالفة شروط الاستخدام',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'approved → blocked',
      build: () => AuthBloc(repository),
      seed: () => AuthAuthenticated(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(driver, DriverAccountStatus.blocked, null),
      ),
      expect: () => [isA<AuthDriverBlocked>()],
    );

    blocTest<AuthBloc, AuthState>(
      // "Blocked → Pending" حرفياً وليس "Blocked → Approved" — رفع الحظر يتطلب
      // مراجعة جديدة، تطابقاً مع admin_unblock_driver في migration (PART 4.5)
      // التي تضبط account_status = pending_review وليس approved مباشرة.
      'blocked → pendingReview (رفع الحظر)',
      build: () => AuthBloc(repository),
      // نعيد استخدام مرجع driver الموجود (كامل الحقول المطلوبة) بدلاً من بناء
      // UserEntity جديد هنا — createdAt/updatedAt مطلوبان (required) في المُنشئ.
      seed: () => AuthDriverBlocked(driver, reason: 'محظور سابقاً لأسباب اختبار'),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(driver, DriverAccountStatus.pendingReview, null),
      ),
      expect: () => [isA<AuthDriverPending>()],
    );
  });

  // ═══════════════════════════════════════════════════════════════════════
  // [دورة المراجعة الثلاثية — Requires Action/Under Review/Approved]
  // انتقالات DriverAccountStatus.underReview الجديدة (MASTER_PLAN.md §4.4-4.6).
  // هذه المجموعة أُضيفت مع تنفيذ الحالة الثلاثية ولم تكن موجودة وقت كتابة
  // المجموعة أعلاه (التي تسبق هذه المهمة وتغطي فقط pendingReview/approved/
  // blocked). لا تُعدَّل الاختبارات القديمة أعلاه — تبقى صحيحة كما هي، لأن
  // pendingReview ("Requires Action") لم يتغيّر سلوكها.
  // ═══════════════════════════════════════════════════════════════════════

  group('انتقالات DriverAccountStatus.underReview ("Under Review")', () {
    blocTest<AuthBloc, AuthState>(
      // السائق يرسل تعديلاته (driver_submit_revision_updates RPC) →
      // account_status ينتقل pending_review → under_review على الـ DB،
      // وهذا الحدث يصل عبر نفس الاشتراك الدائم watchDriverAccountStatus.
      'pendingReview → underReview (السائق أرسل تعديلاته وينتظر مراجعة الأدمن)',
      build: () => AuthBloc(repository),
      seed: () => AuthDriverPending(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(driver, DriverAccountStatus.underReview, null),
      ),
      expect: () => [isA<AuthDriverUnderReview>()],
    );

    blocTest<AuthBloc, AuthState>(
      // الأدمن يوافق عبر admin_resolve_revision_generic(..., 'resolved', NULL)
      // → account_status: under_review → approved مباشرة (وليس عبر pendingReview
      // كخطوة وسيطة). انظر MASTER_PLAN.md §4.6 اختبار 5 على القاعدة الحية.
      'underReview → approved (الأدمن وافق على كل التعديلات)',
      build: () => AuthBloc(repository),
      seed: () => AuthDriverUnderReview(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(driver, DriverAccountStatus.approved, null),
      ),
      expect: () => [isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      // الأدمن يرفض جزئياً عبر admin_resolve_revision_generic(..., 'rejected', p_note)
      // → account_status يعود under_review → pending_review، أي يرجع السائق
      // إلى "Requires Action" وليس إلى حالة معلَّقة جديدة. انظر MASTER_PLAN.md
      // §4.6 اختبار 4. السبب (p_note) يصل كسبب المراجعة الجديد.
      'underReview → pendingReview مع سبب الرفض (رفض جزئي من الأدمن)',
      build: () => AuthBloc(repository),
      seed: () => AuthDriverUnderReview(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(
          driver,
          DriverAccountStatus.pendingReview,
          'الصورة المرفوعة غير واضحة، الرجاء إعادة الرفع',
        ),
      ),
      expect: () => [
        isA<AuthDriverPending>().having(
          (s) => s.revisionReason,
          'revisionReason',
          'الصورة المرفوعة غير واضحة، الرجاء إعادة الرفع',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      // حالة حافة: حظر إداري يمكن أن يصل أثناء under_review أيضاً (ليس فقط
      // من pendingReview/approved كما في المجموعة القديمة أعلاه) — لا يوجد ما
      // يمنع أدمن من حظر سائق قيد المراجعة. يجب ألا يبقى عالقاً في حالة
      // قراءة فقط بلا أي مخرج.
      'underReview → blocked',
      build: () => AuthBloc(repository),
      seed: () => AuthDriverUnderReview(driver),
      act: (bloc) => bloc.add(
        DriverAccountStatusChanged(driver, DriverAccountStatus.blocked, 'مخالفة أثناء المراجعة'),
      ),
      expect: () => [
        isA<AuthDriverBlocked>().having(
          (s) => s.reason,
          'reason',
          'مخالفة أثناء المراجعة',
        ),
      ],
    );
  });

  group('البند 16 (الحالة الثلاثية) — تغيّر account_status إلى/من underReview أثناء جلسة مفتوحة', () {
    test(
      'pendingReview (عند الدخول) ثم underReview خارجياً عبر نفس الاشتراك الدائم — '
      'يختفي زر التعديل فوراً دون إعادة تسجيل الدخول أو إغلاق التطبيق',
      () async {
        final controller = StreamController<
            ({DriverAccountStatus status, String? revisionReason})>();
        addTearDown(controller.close);

        when(() => repository.getCurrentUser())
            .thenAnswer((_) async => Right(driver));
        when(() => repository.watchDriverAccountStatus(driver.id))
            .thenAnswer((_) => controller.stream);

        final bloc = AuthBloc(repository);
        addTearDown(bloc.close);

        final states = <AuthState>[];
        final sub = bloc.stream.listen(states.add);
        addTearDown(sub.cancel);

        // 1) الدخول الأول — القيمة الأولية pendingReview ("Requires Action").
        bloc.add(CheckAuthStatus());
        await Future.delayed(const Duration(milliseconds: 20));
        controller.add((status: DriverAccountStatus.pendingReview, revisionReason: null));
        await Future.delayed(const Duration(milliseconds: 20));

        expect(
          states.whereType<AuthDriverPending>(),
          isNotEmpty,
          reason: 'يجب أن يصل السائق إلى AuthDriverPending عند pendingReview الأولي',
        );

        // 2) 🔑 السائق نفسه يضغط "إرسال" داخل DriverTargetedEditScreen (مثال
        // حي، لا نستدعي RPC فعلياً هنا — نحاكي فقط القيمة التي سيدفعها Realtime
        // بعد نجاح driver_submit_revision_updates) — بدون أي bloc.add() يدوي
        // منا، بل عبر نفس الـ Stream الدائم تماماً كما في اختبار الحظر أعلاه.
        controller.add((status: DriverAccountStatus.underReview, revisionReason: null));
        await Future.delayed(const Duration(milliseconds: 20));

        expect(
          states.last,
          isA<AuthDriverUnderReview>(),
          reason: 'يجب أن ينتقل السائق فوراً إلى AuthDriverUnderReview عبر '
              'الاشتراك الدائم نفسه فور نجاح الإرسال، وهذا هو بالضبط ما يخفي '
              'زر "تعديل الملف الشخصي" دون أي حاجة لإعادة تشغيل التطبيق — '
              'الخلل الأصلي الموصوف في MASTER_PLAN.md القسم 3.3.',
        );

        // تأكيد إضافي: نفس نمط اختبار الحظر أعلاه — اشتراك واحد طوال الجلسة.
        verify(() => repository.watchDriverAccountStatus(driver.id)).called(1);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════
  // البند 16 — السيناريو الحرج: سائق بجلسة مفتوحة فعلاً (لا يعيد تسجيل
  // الدخول) يُحظر أو يُسحب اعتماده من لوحة تحكم أخرى أثناء استخدامه.
  //
  // الفرق الجوهري عن المجموعة أعلاه: هنا لا نضيف DriverAccountStatusChanged
  // يدوياً — بل نمرّ عبر CheckAuthStatus الفعلي الذي يستدعي
  // _startWatchingDriverStatus داخلياً، ثم ندفع قيمة ثانية إلى *نفس* الـ
  // StreamController المُستخدَم كتنفيذ watchDriverAccountStatus، لمحاكاة تغيير
  // خارجي حقيقي يصل عبر الاشتراك الدائم. هذا يختبر تحديداً أن الاشتراك
  // يبقى فعّالاً طوال الجلسة (البند 10 من المرحلة ج) وليس فحصاً لمرة واحدة
  // فقط عند الدخول — وهو بالضبط الخلل الجذري الموصوف في MASTER_PLAN القسم 2.2.
  // ═══════════════════════════════════════════════════════════════════════

  group('البند 16 — تغيّر account_status أثناء جلسة مفتوحة بالفعل', () {
    test(
      'approved (عند الدخول) ثم blocked خارجياً عبر نفس الاشتراك الدائم، دون إعادة تسجيل الدخول',
      () async {
        final controller = StreamController<
            ({DriverAccountStatus status, String? revisionReason})>();
        addTearDown(controller.close);

        when(() => repository.getCurrentUser())
            .thenAnswer((_) async => Right(driver));
        when(() => repository.watchDriverAccountStatus(driver.id))
            .thenAnswer((_) => controller.stream);

        final bloc = AuthBloc(repository);
        addTearDown(bloc.close);

        final states = <AuthState>[];
        final sub = bloc.stream.listen(states.add);
        addTearDown(sub.cancel);

        // 1) الدخول الأول — القيمة الأولية approved (يحاكي emitCurrent()).
        bloc.add(CheckAuthStatus());
        await Future.delayed(const Duration(milliseconds: 20));
        controller.add((status: DriverAccountStatus.approved, revisionReason: null));
        await Future.delayed(const Duration(milliseconds: 20));

        expect(
          states.whereType<AuthAuthenticated>(),
          isNotEmpty,
          reason: 'يجب أن يصل السائق إلى AuthAuthenticated عند approved الأولي',
        );

        // 2) 🔑 الآن — وبدون أي bloc.add() جديد من جهتنا — ندفع تغييراً خارجياً
        // (حظر) إلى *نفس* الـ Stream. هذا يحاكي بالضبط ما يحدث فعلياً: أدمن
        // يحظر السائق من لوحة تحكم أخرى بينما تطبيق السائق مفتوح على شاشة
        // الرحلات، دون أن يغلق السائق التطبيق أو يعيد تسجيل الدخول.
        controller.add((
          status: DriverAccountStatus.blocked,
          revisionReason: 'محاكاة حظر إداري أثناء جلسة مفتوحة',
        ));
        await Future.delayed(const Duration(milliseconds: 20));

        expect(
          states.last,
          isA<AuthDriverBlocked>().having(
            (s) => s.reason,
            'reason',
            'محاكاة حظر إداري أثناء جلسة مفتوحة',
          ),
          reason: 'يجب أن يُطرَد السائق فوراً عبر الاشتراك الدائم نفسه، '
              'دون الحاجة لإغلاق التطبيق أو تسجيل دخول جديد — هذا هو '
              'الخلل الجذري الموصوف في MASTER_PLAN.md القسم 2.2 الذي '
              'صُمِّم البند 10 من المرحلة ج لحله.',
        );

        // تأكيد إضافي: watchDriverAccountStatus استُدعيت مرة واحدة فقط طوال
        // الجلسة (وليس مرتين) — يثبت أن التغيير الثاني وصل عبر نفس الاشتراك
        // الدائم، وليس عبر إعادة اشتراك جديد ناتج عن حدث دخول ثانٍ وهمي.
        verify(() => repository.watchDriverAccountStatus(driver.id)).called(1);
      },
    );
  });
}
