
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppToast {
  static void error(String message) => Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppColors.primary,
        textColor: AppColors.textPrimary,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_LONG,
        fontSize: 14,
      );

  static void success(String message) => Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppColors.success,
        textColor: AppColors.textPrimary,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_SHORT,
        fontSize: 14,
      );

  static void warning(String message) => Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppColors.warning,
        textColor: const Color(0xFF1A1A1A),
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_LONG,
        fontSize: 14,
      );

  static void info(String message) => Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppColors.surfaceElevated,
        textColor: AppColors.textSecondary,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_SHORT,
        fontSize: 14,
      );

  static void dismiss() => Fluttertoast.cancel();
}
