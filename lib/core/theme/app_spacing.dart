/// نظام المسافات الموحَّد
import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double xxl  = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;

  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets screen = EdgeInsets.fromLTRB(xl, lg, xl, xxxl);
  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardLg = EdgeInsets.all(xl);
  static const EdgeInsets sheet = EdgeInsets.fromLTRB(xl, lg, xl, 34);
  static const EdgeInsets chip = EdgeInsets.symmetric(horizontal: md, vertical: xs);
  static const EdgeInsets btnSm = EdgeInsets.symmetric(horizontal: lg, vertical: sm);
}
