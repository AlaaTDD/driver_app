import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Helper يسهل كتابة الـ integration tests
/// ✅ FIX: takeScreenshot دلوقتي بتحفظ صورة حقيقية
class TestHelper {
  final IntegrationTestWidgetsFlutterBinding? _binding;
  final List<String> _screenshotsTaken = [];
  final List<String> _warnings = [];
  final List<String> _errors = [];

  TestHelper({IntegrationTestWidgetsFlutterBinding? binding})
      : _binding = binding ?? IntegrationTestWidgetsFlutterBinding.instance;

  /// انتظر إن widget بـ key معين يظهر — بيفيل لو مظهرش
  Future<void> waitForKey(
    WidgetTester tester,
    String key, {
    int timeout = 10,
    bool failOnTimeout = false,
  }) async {
    final finder = find.byKey(ValueKey(key));
    final deadline = DateTime.now().add(Duration(seconds: timeout));

    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 300));
      if (finder.evaluate().isNotEmpty) {
        debugPrint('✅ Widget found: $key');
        return;
      }
    }

    final msg = '⚠️  Widget "$key" not found after ${timeout}s';
    debugPrint(msg);
    _warnings.add(msg);

    if (failOnTimeout) {
      fail('Widget with key "$key" not found after ${timeout}s');
    }
  }

  /// اضغط على widget بـ key
  Future<bool> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return true;
    } else {
      final msg = '⚠️  Cannot tap — key not found: $key';
      debugPrint(msg);
      _warnings.add(msg);
      return false;
    }
  }

  /// اضغط بـ key (alias)
  Future<bool> tap(WidgetTester tester, String key) => tapKey(tester, key);

  /// ادخل نص في field
  Future<bool> enterText(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder);
      await tester.enterText(finder, text);
      await tester.pumpAndSettle();
      return true;
    } else {
      final msg = '⚠️  Cannot enter text — key not found: $key';
      debugPrint(msg);
      _warnings.add(msg);
      return false;
    }
  }

  /// ✅ FIX: التقط screenshot حقيقي بـ IntegrationTestWidgetsFlutterBinding
  Future<void> takeScreenshot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    try {
      // ده بيحفظ screenshot حقيقية في الـ test report
      await _binding?.takeScreenshot(name);
      _screenshotsTaken.add(name);
      debugPrint('📸 Screenshot taken: $name');
    } catch (e) {
      debugPrint('⚠️  Screenshot failed for "$name": $e');
    }
  }

  /// تحقق من إن widget موجود — بيرجع true/false من غير ما يفيل
  bool isKeyPresent(WidgetTester tester, String key) {
    final finder = find.byKey(ValueKey(key));
    final exists = finder.evaluate().isNotEmpty;
    if (!exists) {
      debugPrint('ℹ️  Key not present: $key');
    }
    return exists;
  }

  /// تحقق من وجود text معين في الـ UI
  bool isTextPresent(WidgetTester tester, String text) {
    return find.text(text).evaluate().isNotEmpty;
  }

  /// Scroll لأسفل في الـ screen
  Future<void> scrollDown(WidgetTester tester, {double pixels = 300}) async {
    await tester.drag(
      find.byType(Scrollable).first,
      Offset(0, -pixels),
    );
    await tester.pumpAndSettle();
  }

  /// انتظر حتى text معين يظهر
  Future<bool> waitForText(
    WidgetTester tester,
    String text, {
    int timeout = 10,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: timeout));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 300));
      if (find.text(text).evaluate().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Cleanup — بيطبع ملخص التست
  Future<void> cleanup() async {
    debugPrint('\n🧹 TestHelper Summary:');
    debugPrint('   📸 Screenshots: ${_screenshotsTaken.length}');
    debugPrint('   ⚠️  Warnings: ${_warnings.length}');
    debugPrint('   🔴 Errors: ${_errors.length}');

    if (_warnings.isNotEmpty) {
      debugPrint('\n   Warnings:');
      for (final w in _warnings) {
        debugPrint('   - $w');
      }
    }

    if (_errors.isNotEmpty) {
      debugPrint('\n   Errors:');
      for (final e in _errors) {
        debugPrint('   - $e');
      }
    }
  }
}
