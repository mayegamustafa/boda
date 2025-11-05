import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razinshop_rider/config/app_color.dart';
import 'package:razinshop_rider/config/app_text.dart';

class NotificationPermissionService {
  static Future<bool> requestNotificationPermission() async {
    try {
      // Check current status
      final status = await Permission.notification.status;
      print('Current notification permission status: $status');

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        // Request permission
        final result = await Permission.notification.request();
        print('Notification permission request result: $result');
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        // Open settings for the user to manually enable
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  static Future<void> showNotificationPermissionDialog(BuildContext context) async {
    final status = await Permission.notification.status;
    
    if (status.isGranted) {
      return; // Already granted
    }

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications, color: AppColor.primaryColor),
            SizedBox(width: 8.w),
            Text(
              'Enable Notifications',
              style: AppTextStyle.normalBody.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get notified about:',
              style: AppTextStyle.normalBody,
            ),
            SizedBox(height: 8.h),
            _buildNotificationItem('🚚 New delivery requests'),
            _buildNotificationItem('📍 Order status updates'),
            _buildNotificationItem('💰 Payment confirmations'),
            _buildNotificationItem('⏰ Important delivery reminders'),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColor.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, 
                       color: AppColor.primaryColor, 
                       size: 20.r),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'You can disable notifications anytime in your device settings.',
                      style: AppTextStyle.smallBody.copyWith(
                        color: AppColor.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(
              'Skip',
              style: AppTextStyle.normalBody.copyWith(
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
              
              final granted = await requestNotificationPermission();
              
              if (context.mounted) {
                if (granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8.w),
                          Text('Notifications enabled! 🔔'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  _showNotificationDeniedDialog(context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColor.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Enable Notifications',
              style: AppTextStyle.normalBody.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildNotificationItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Text(
        text,
        style: AppTextStyle.smallBody.copyWith(
          height: 1.4,
        ),
      ),
    );
  }

  static void _showNotificationDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8.w),
            Text('Notifications Disabled'),
          ],
        ),
        content: Text(
          'Notification permission was denied. You can enable it manually in your device settings.\n\nGo to: Settings > Apps > Total Ride > Notifications',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  static Future<void> initializeNotifications(BuildContext context) async {
    // Check if we need to request notification permission
    final status = await Permission.notification.status;
    
    if (status.isDenied) {
      // Show permission dialog after a short delay
      Future.delayed(Duration(seconds: 2), () {
        if (context.mounted) {
          showNotificationPermissionDialog(context);
        }
      });
    }
  }
}