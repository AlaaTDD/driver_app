import 'package:flutter/material.dart';

abstract class ThemeState {
  ThemeMode get themeMode;
  bool get isDark;
}

class ThemeDark extends ThemeState {
  @override
  ThemeMode get themeMode => ThemeMode.dark;
  @override
  bool get isDark => true;
}

class ThemeLight extends ThemeState {
  @override
  ThemeMode get themeMode => ThemeMode.light;
  @override
  bool get isDark => false;
}
