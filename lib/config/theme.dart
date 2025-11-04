import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razinshop_rider/config/app_color.dart';

class AppTheme {
  AppTheme._();
  static ThemeData lightTheme = ThemeData(
    fontFamily: 'Mulish',
    useMaterial3: true,
    scaffoldBackgroundColor: AppColor.greyBackgroundColor,
    canvasColor: AppColor.whiteColor,
    brightness: Brightness.light,
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(
        color: Colors.black,
      ),
    ),
    drawerTheme: DrawerThemeData(scrimColor: Colors.black.withValues(alpha: 0.7)),
  );

  static ThemeData darkTheme = ThemeData(
    fontFamily: 'Mulish',
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
    brightness: Brightness.dark,
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.white.withValues(alpha: 0.5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColor.borderColor.withValues(alpha: 0.8),
      thickness: 0.5,
    ),
    drawerTheme: DrawerThemeData(scrimColor: Colors.grey.withValues(alpha: 0.3)),
  );

  static InputDecoration inputDecoration = InputDecoration(
    // hintStyle: AppTextStyle.normalBody.copyWith(color: AppColor.greyColor),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.r),
      borderSide: const BorderSide(
        color: AppColor.borderColor,
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.r),
      borderSide: const BorderSide(
        color: AppColor.borderColor,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.r),
      borderSide: const BorderSide(
        color: AppColor.borderColor,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.r),
      borderSide: BorderSide(
        color: AppColor.primaryColor,
      ),
    ),
  );
}
