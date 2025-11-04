import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:razinshop_rider/components/my_custom_button.dart';
import 'package:razinshop_rider/config/app_color.dart';
import 'package:razinshop_rider/config/app_text.dart';
import 'package:razinshop_rider/controllers/misc/providers.dart';
import 'package:razinshop_rider/controllers/order_controller/order_controller.dart';
import 'package:razinshop_rider/generated/l10n.dart';
import 'package:razinshop_rider/utils/context_less_navigate.dart';

class DatePickerLayout extends ConsumerWidget {
  const DatePickerLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeaderWidget(context: context, ref: ref),
            Divider(
              height: 0,
              color: AppColor.greyColor,
              thickness: 2,
            ),
            _buildBodyWidget(context: context, ref: ref),
            // Gap(20.h)
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWidget(
      {required BuildContext context, required WidgetRef ref}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h)
          .copyWith(bottom: 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  // Close the screen and reset the date
                  ref.read(selectedDate.notifier).state = null;
                  context.nav.pop();
                },
                icon: const Icon(
                  Icons.close,
                  size: 30,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Reset the date and filter state
                  ref.read(selectedDate.notifier).state = null;
                  ref.read(orderHistoryFilterProvider.notifier).state =
                      TodoListFilter.all;
                  ref.invalidate(orderHistoryProvider);
                  // Force rebuild of CalendarDatePicker2
                  ref.invalidate(selectedDate);
                },
                child: Text(
                  S.of(context).reset,
                  style: AppTextStyle.title.copyWith(
                    color: AppColor.redColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            ],
          ),
          Gap(20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate(date: ref.watch(selectedDate) ?? DateTime.now()),
                style: AppTextStyle.title
                    .copyWith(fontSize: 30.sp, fontWeight: FontWeight.bold),
              ),
              const SizedBox(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyWidget(
      {required BuildContext context, required WidgetRef ref}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          child: CalendarDatePicker2(
            key: ValueKey(ref.watch(selectedDate)),
            config: CalendarDatePicker2Config(
              calendarType: CalendarDatePicker2Type.single,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              calendarViewMode: CalendarDatePicker2Mode.day,
              selectedDayHighlightColor: AppColor.primaryColor,
              lastMonthIcon: Icon(
                Icons.arrow_back_ios,
                size: 16.sp,
              ),
              yearTextStyle:
                  AppTextStyle.title.copyWith(fontWeight: FontWeight.bold),
              selectedYearTextStyle: AppTextStyle.title.copyWith(
                  fontWeight: FontWeight.bold, color: AppColor.whiteColor),
              nextMonthIcon: Icon(
                Icons.arrow_forward_ios,
                size: 16.sp,
              ),
              controlsTextStyle:
                  AppTextStyle.normalBody.copyWith(fontSize: 16.sp),
              weekdayLabelTextStyle:
                  AppTextStyle.normalBody.copyWith(fontWeight: FontWeight.w500),
              dayTextStyle: AppTextStyle.normalBody.copyWith(
                fontWeight: FontWeight.w500,
              ),
              selectedDayTextStyle: AppTextStyle.normalBody.copyWith(
                color: AppColor.whiteColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            value: [ref.watch(selectedDate) ?? DateTime.now()],
            onDisplayedMonthChanged: (v) {},
            onValueChanged: (date) {
              ref.read(selectedDate.notifier).state = date.first;
              if (ref.read(selectedDateFilter) != '') {
                // ignore: unused_result
                ref.refresh(selectedDateFilter);
              }
            },
          ),
        ),
        SizedBox(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                Divider(
                  height: 0,
                  color: AppColor.greyColor,
                  thickness: 2,
                ),
              ],
            ),
          ),
        ),
        Gap(30.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: MyCustomButton(
                  btnText: S.of(context).cancel,
                  textColor: Colors.black,
                  btnColor: AppColor.greyColor.withOpacity(0.25),
                  onTap: () {
                    context.nav.pop(context);
                    ref.read(selectedDate.notifier).state = null;
                    ref.read(orderHistoryFilterProvider.notifier).state =
                        TodoListFilter.all;
                    // Optionally, clear any other related states here
                  },
                ),
              ),
              Gap(20.w),
              Flexible(
                flex: 1,
                child: MyCustomButton(
                  btnText: S.of(context).apply,
                  onTap: () {
                    final formatter = DateFormat('yyyy-MM-dd', 'en_US');
                    final formattedDate = formatter
                        .format(ref.read(selectedDate) ?? DateTime.now());
                    ref
                        .read(orderHistoryProvider.notifier)
                        .searchOrderHistoryByDate(formattedDate);

                    context.nav.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
        Gap(10.h),
      ],
    );
  }

  String formattedDate({required DateTime date}) {
    return DateFormat('E, MMM d').format(date.toLocal());
  }

  List<String> filterOption({required BuildContext context}) {
    return [
      "Tody",
      "This Week",
      "Last Week",
      "This Month",
      "Last Month",
      "This Year",
      "Last Year",
    ];
  }
}
