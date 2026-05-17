import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

class AppToast {
  static void error(String message) => Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppColors.error,
        textColor: AppColors.white,
        gravity: ToastGravity.TOP,
        toastLength: Toast.LENGTH_LONG,
        fontSize: 14,
      );

  static void success(String message) => Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppColors.success,
        textColor: AppColors.white,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_SHORT,
        fontSize: 14,
      );

  static void warning(String message) => Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppColors.warning,
        textColor: AppColors.black,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_LONG,
        fontSize: 14,
      );

  static void info(String message) => Fluttertoast.showToast(
        msg: message,
        backgroundColor: AppColors.darkElevated,
        textColor: AppColors.darkTextSecondary,
        gravity: ToastGravity.BOTTOM,
        toastLength: Toast.LENGTH_SHORT,
        fontSize: 14,
      );

  static void dismiss() => Fluttertoast.cancel();
}
