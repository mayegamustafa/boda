import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:razinshop_rider/components/my_custom_button.dart';
import 'package:razinshop_rider/config/app_color.dart';
import 'package:razinshop_rider/config/theme.dart';
import 'package:razinshop_rider/controllers/auth_controller/auth_controller.dart';
import 'package:razinshop_rider/gen/assets.gen.dart';
import 'package:razinshop_rider/generated/l10n.dart';
import 'package:razinshop_rider/routers.dart';
import 'package:razinshop_rider/utils/context_less_navigate.dart';
import 'package:razinshop_rider/utils/extensions.dart';
import 'package:razinshop_rider/views/auth/layouts/confirm_otp_layout.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _formKey = GlobalKey<FormBuilderState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? Colors.black : AppColor.whiteColor,
      appBar: AppBar(
        backgroundColor: context.isDark ? Colors.black : AppColor.whiteColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          color: AppColor.primaryColor,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Assets.pngs.delivery.image(width: 200.w),
          Gap(65.h),
          FormBuilder(
            key: _formKey,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).forgotPassword,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Gap(12.h),
                  Text(
                    "Enter your registered phone number with country code (e.g., +256712345678) or without for local numbers. We'll send you an OTP code to reset your password.",
                    style: TextStyle(
                      color: AppColor.greyColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Gap(24.h),
                  Text(
                    S.of(context).phoneNumber,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Gap(12.h),
                  FormBuilderTextField(
                    name: "phone",
                    keyboardType: TextInputType.phone,
                    decoration: AppTheme.inputDecoration.copyWith(
                      hintText: "Enter phone number (with country code: +256...)",
                      hintStyle: TextStyle(
                        color: AppColor.greyColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    validator: FormBuilderValidators.compose(
                      [
                        FormBuilderValidators.required(),
                        (value) {
                          if (value == null || value.isEmpty) {
                            return 'Phone number is required';
                          }
                          
                          // Remove spaces and other formatting
                          String cleanedPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
                          
                          // Check if it starts with + (international format)
                          if (cleanedPhone.startsWith('+')) {
                            // For international format: +[country code][number]
                            // Minimum: +1234567890 (11 chars), Maximum: +123456789012345 (16 chars)
                            if (cleanedPhone.length < 10 || cleanedPhone.length > 16) {
                              return 'Phone number with country code should be 10-16 digits';
                            }
                            // Check if all characters after + are digits
                            if (!RegExp(r'^\+\d+$').hasMatch(cleanedPhone)) {
                              return 'Invalid phone number format. Use +[country code][number]';
                            }
                          } else {
                            // For local format (without country code)
                            // Should be digits only, 9-15 digits
                            if (cleanedPhone.length < 9 || cleanedPhone.length > 15) {
                              return 'Phone number should be 9-15 digits or include country code (+256...)';
                            }
                            // Check if all characters are digits
                            if (!RegExp(r'^\d+$').hasMatch(cleanedPhone)) {
                              return 'Phone number should contain only digits or start with + for country code';
                            }
                          }
                          
                          return null; // Valid
                        },
                      ],
                    ),
                  ),
                  Gap(30.h),
                  // mycustombutton
                  Consumer(
                    builder: (context, ref, child) {
                      final loading = ref.watch(sendOTPProvider);
                      return loading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : MyCustomButton(
                              onTap: () {
                                if (_formKey.currentState!.saveAndValidate()) {
                                  ref
                                      .read(sendOTPProvider.notifier)
                                      .sendOTP(
                                        phone: _formKey.currentState!
                                            .fields['phone']!.value
                                            .toString(),
                                        isForgetPass: true,
                                      )
                                      .then((value) {
                                    if (value != null) {
                                      context.nav.pushNamed(
                                        Routes.confirmOTP,
                                        arguments: ConfirmOTPScreenArguments(
                                          phoneNumber: _formKey.currentState!
                                              .fields['phone']!.value
                                              .toString(),
                                          isPasswordRecover: true,
                                          userData: {},
                                          otp: value,
                                        ),
                                      );
                                    }
                                  });
                                }
                              },
                              btnText: S.of(context).sendOTP,
                            );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
