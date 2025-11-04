import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:razinshop_rider/config/app_text.dart';
import 'package:razinshop_rider/controllers/notification_controller/notification_controller.dart';
import 'package:razinshop_rider/gen/assets.gen.dart';
import 'package:razinshop_rider/models/notification_model.dart' as model;
import 'package:razinshop_rider/utils/extensions.dart';

class NotificationScreen extends ConsumerWidget {
  NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.isDark ? Colors.black : Colors.white,
        elevation: 0,
        surfaceTintColor: context.isDark ? Colors.black : Colors.white,
        title: Text(
          'Notifications',
          style: AppTextStyle.normalBody.copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset(
            Assets.svgs.backArrow,
            colorFilter: ColorFilter.mode(
              context.isDark ? Colors.white : Colors.black,
              BlendMode.srcIn,
            ),
          ),
          color: context.isDark ? Colors.white : Colors.black,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ref
          .watch(notificationControllerProvider)
          .when(
            data: (data) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8).r,
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    return _NotificationCard(notification: data[index]);
                  },
                ),
              );
            },
            error: (e, s) {
              return Center(child: Text('Error: $e'));
            },
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
          ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  _NotificationCard({required this.notification});
  final model.Notification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final isRead = !ref.watch(isReadProvider).contains(index);
    return Column(
      children: [
        Stack(
          children: [
            InkWell(
              onTap: () {
                ref
                    .read(notificationControllerProvider.notifier)
                    .isReadNotification(notification);
              },
              child: Container(
                padding: const EdgeInsets.all(12).r,
                decoration:
                    !context.isDark
                        ? ShapeDecoration(
                          color:
                              !notification.isRead!
                                  ? Colors.white
                                  : const Color(0xFFF2E9FE),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color:
                                  !notification.isRead!
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFFF2E9FE),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12).r,
                          ),
                        )
                        : ShapeDecoration(
                          color:
                              !notification.isRead!
                                  ? Colors.grey.withOpacity(0.5)
                                  : Colors.grey.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color:
                                  !notification.isRead!
                                      ? Colors.grey.withOpacity(0.5)
                                      : Colors.grey.withOpacity(0.2),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12).r,
                          ),
                        ),
                child: Row(
                  children: [
                    Container(
                      height: 45.r,
                      width: 45.r,
                      padding: const EdgeInsets.all(10),
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: SvgPicture.asset(Assets.svgs.notification),
                    ),
                    Gap(20.r),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title ?? '',
                            style: AppTextStyle.normalBody.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                notification.createdAt ?? '',
                                style: AppTextStyle.normalBody.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              // const SizedBox(width: 6),
                              // Container(
                              //   width: 4,
                              //   height: 4,
                              //   decoration: const ShapeDecoration(
                              //     color: Color(0xFF94A3B8),
                              //     shape: OvalBorder(),
                              //   ),
                              // ),
                              // const SizedBox(width: 6),
                              // Text(
                              //   'Now',
                              //   style: AppTextStyle.normalBody.copyWith(
                              //     color: const Color(0xFF64748B),
                              //     fontSize: 12.sp,
                              //     fontWeight: FontWeight.w400,
                              //   ),
                              // ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child:
                  !notification.isRead!
                      ? const SizedBox()
                      : Container(
                        width: 10.r,
                        height: 10.r,
                        decoration: const ShapeDecoration(
                          color: Color(0xFFAC71F4),
                          shape: OvalBorder(),
                        ),
                      ),
            ),
          ],
        ),
        Gap(10.h),
      ],
    );
  }
}
