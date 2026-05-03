
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences _prefs;
  static const _key = 'app_theme_dark';

  ThemeBloc(this._prefs) : super(ThemeDark()) {
    on<LoadSavedTheme>(_onLoad);
    on<ToggleTheme>(_onToggle);
  }

  void _onLoad(LoadSavedTheme event, Emitter<ThemeState> emit) {
    final isDark = _prefs.getBool(_key) ?? true;
    emit(isDark ? ThemeDark() : ThemeLight());
  }

  void _onToggle(ToggleTheme event, Emitter<ThemeState> emit) {
    final isDark = state is ThemeDark;
    _prefs.setBool(_key, !isDark);
    emit(isDark ? ThemeLight() : ThemeDark());
  }
}
