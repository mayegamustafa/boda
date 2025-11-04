import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razinshop_rider/config/app_color.dart';
import 'package:razinshop_rider/config/app_text.dart';

class MyCustomButton extends StatelessWidget {
  const MyCustomButton({
    super.key,
    this.btnColor,
    required this.onTap,
    required this.btnText,
    this.textColor,
  });
  final String btnText;
  final Function onTap;
  final Color? btnColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: btnColor ?? AppColor.primaryColor,
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: InkWell(
          onTap: () {
            onTap();
          },
          borderRadius: BorderRadius.circular(100.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 15.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100.r),
            ),
            child: Center(
              child: Text(
                btnText,
                style: AppTextStyle.normalBody.copyWith(
                  color: textColor ?? AppColor.whiteColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
