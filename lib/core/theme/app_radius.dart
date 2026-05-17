import 'package:flutter/material.dart';

/// نظام الزوايا الموحَّد
class AppRadius {
  AppRadius._();

  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 14.0;
  static const double xl = 16.0;
  static const double xxl = 20.0;
  static const double xxxl = 24.0;
  static const double huge = 32.0;
  static const double full = 100.0;

  static final xs_ = BorderRadius.circular(xs);
  static final sm_ = BorderRadius.circular(sm);
  static final md_ = BorderRadius.circular(md);
  static final lg_ = BorderRadius.circular(lg);
  static final xl_ = BorderRadius.circular(xl);
  static final xxl_ = BorderRadius.circular(xxl);
  static final xxxl_ = BorderRadius.circular(xxxl);
  static final huge_ = BorderRadius.circular(huge);
  static final full_ = BorderRadius.circular(full);

  static final sheetTop =
      const BorderRadius.vertical(top: Radius.circular(xxxl));
  static final sheetTopXl =
      const BorderRadius.vertical(top: Radius.circular(huge));
}
