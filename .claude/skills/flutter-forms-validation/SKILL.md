---
name: Flutter Forms & Validation
description: >
  يُفعَّل عند بناء أو تعديل أي Form، TextFormField، AppPhoneField،
  DropdownButtonFormField، أو أي شاشة تسجيل/تعديل بيانات في المشروع.
  يضمن forms صحيحة ومتسقة مع معايير المشروع الفعلية.
priority: HIGH
---

# Flutter Forms & Validation — Snapix

> كل form في المشروع يجب أن تكون: آمنة، متسقة، مدعومة بـ AppPhoneField، وخالية من deprecated APIs.

---

## §1 القواعد الحديدية

```
□ GlobalKey<FormState> لكل form
□ Form.validate() قبل أي submit
□ mounted check بعد كل await في _submit()
□ TextEditingController.dispose() في dispose() لكل controller
□ prefixIcon: const Icon(...) دائماً (ليس Icon(...) بدون const)
□ DropdownButtonFormField → initialValue (لا value — deprecated في Flutter 3.33+)
□ if (...) { ... } حتى في validators من سطر واحد
```

---

## §2 AppPhoneField — استخدامه الصحيح

```dart
// ✅ CORRECT — onChanged يستقبل String (E.164)
String _fullPhone = '';

AppPhoneField(
  initialCountryCode: 'EG',          // افتراضي للمشروع
  textInputAction: TextInputAction.next,
  onChanged: (number) {
    _fullPhone = number;              // "+201001234567"
  },
)

// ❌ WRONG — onChanged لا تستقبل PhoneNumber
AppPhoneField(
  onChanged: (PhoneNumber phone) {   // ← type error
    _fullPhone = phone.completeNumber;
  },
)

// ملاحظة: AppPhoneField تعمل كـ wrapper على intl_phone_field
// تُرجع E.164 number كـ String مباشرة
// الـ validation مدمج — لا داعي لـ validator خارجي
```

---

## §3 TextFormField — القالب القياسي

```dart
// ✅ CORRECT — pattern كامل
TextFormField(
  controller: _nameController,
  textInputAction: TextInputAction.next,
  decoration: InputDecoration(
    labelText: l.fullName,
    prefixIcon: const Icon(Icons.person_outlined),  // ✅ const إلزامي
  ),
  validator: (v) {
    if (v == null || v.isEmpty) {          // ✅ curly braces حتى في سطر
      return l.enterFullName;
    }
    return null;
  },
),

// ❌ WRONG — أخطاء شائعة
TextFormField(
  decoration: InputDecoration(
    prefixIcon: Icon(Icons.person_outlined),  // ❌ بدون const → warning
  ),
  validator: (v) {
    if (v == null || v.isEmpty)
      return l.enterFullName;   // ❌ بدون curly braces
  },
)
```

---

## §4 DropdownButtonFormField — القالب القياسي

```dart
// ✅ CORRECT — Flutter 3.33+
DropdownButtonFormField<String>(
  initialValue: _selectedValue,         // ✅ initialValue (لا value)
  decoration: InputDecoration(
    labelText: l.vehicleType,
    prefixIcon: const Icon(Icons.directions_car_rounded),
  ),
  dropdownColor: context.cardColor,
  items: options.map((opt) => DropdownMenuItem<String>(
    value: opt.key,
    child: Text(opt.label, style: TextStyle(color: context.textPrimary)),
  )).toList(),
  onChanged: (v) => setState(() => _selectedValue = v),
)

// ❌ WRONG — deprecated
DropdownButtonFormField<String>(
  value: _selectedValue,   // ❌ deprecated في 3.33+
  ...
)
```

---

## §5 Submit Pattern الإلزامي

```dart
// ✅ CORRECT — pattern كامل للـ submit
Future<void> _submit() async {
  // 1. Validate
  if (!_formKey.currentState!.validate()) return;

  // 2. Custom checks (passwords, etc.)
  if (_passwordController.text != _confirmPasswordController.text) {
    AppToast.error(l.passwordsNotMatch);
    return;
  }

  // 3. Loading state
  setState(() => _isLoading = true);

  try {
    // 4. Async work
    final result = await _repo.submit(...);

    // 5. mounted check ALWAYS after await
    if (!mounted) return;

    // 6. Success
    context.go(AppRoutes.home);
  } on AppException catch (e) {
    if (!mounted) return;
    AppToast.error(ErrorMapper.getErrorMessage(context, e.message));
  } catch (e, st) {
    AppLogger.error('Submit failed', tag: 'Screen', error: e, stackTrace: st);
    if (!mounted) return;
    AppToast.error(ErrorMapper.getErrorMessage(context, 'unexpectedError'));
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

// ❌ WRONG
void _submit() {
  _repo.submit();  // ← بدون validate, بدون mounted, بدون loading
}
```

---

## §6 الـ Screens المرجعية في المشروع

| Screen | المسار | الـ Pattern |
|---|---|---|
| `RegisterUserScreen` | `features/auth/presentation/screens/register_user_screen.dart` | أبسط form مع phone |
| `RegisterDriverScreen` | `features/auth/presentation/screens/register_driver_screen.dart` | form معقد مع image upload + dropdown |

---

## §7 قائمة تحقق سريعة

```
□ GlobalKey<FormState> معرّف
□ Form(..., key: _formKey)
□ _formKey.currentState!.validate() في _submit()
□ كل controller يُـdispose في dispose()
□ AppPhoneField.onChanged يستقبل String
□ prefixIcon: const Icon(...) في كل الحقول
□ DropdownButtonFormField → initialValue
□ if validators → {}
□ mounted check بعد كل await
□ AppButton(isLoading: _isLoading, onPressed: _submit)
□ لا نص hardcoded → كله من AppLocalizations
```
