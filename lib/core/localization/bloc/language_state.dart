// lib/core/localization/bloc/language_state.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class LanguageState extends Equatable {
  const LanguageState();

  @override
  List<Object?> get props => [];
}

class LanguageInitial extends LanguageState {}

class LanguageLoaded extends LanguageState {
  final String languageCode;

  const LanguageLoaded(this.languageCode);

  Locale get locale => Locale(languageCode);

  @override
  List<Object?> get props => [languageCode];
}
