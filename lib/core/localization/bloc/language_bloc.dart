// lib/core/localization/bloc/language_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_event.dart';
import 'language_state.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  final SharedPreferences _prefs;
  static const _languageKey = 'app_language';

  LanguageBloc(this._prefs) : super(const LanguageLoaded('ar')) {
    on<LoadSavedLanguage>(_onLoadSaved);
    on<ChangeLanguage>(_onChangeLanguage);
  }

  Future<void> _onLoadSaved(
    LoadSavedLanguage event,
    Emitter<LanguageState> emit,
  ) async {
    final savedLang = _prefs.getString(_languageKey) ?? 'ar';
    emit(LanguageLoaded(savedLang));
  }

  Future<void> _onChangeLanguage(
    ChangeLanguage event,
    Emitter<LanguageState> emit,
  ) async {
    await _prefs.setString(_languageKey, event.languageCode);
    emit(LanguageLoaded(event.languageCode));
  }
}
