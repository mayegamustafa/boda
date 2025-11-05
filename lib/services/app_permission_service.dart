import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_permission_service.g.dart';

@riverpod
AppPermissionService appPermissionService(AppPermissionServiceRef ref) {
  return AppPermissionService();
}

class AppPermissionService {
  
  /// Check if notification permission is granted
  Future<bool> isNotificationEnabled() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    try {
      // Check current status
      final status = await Permission.notification.status;
      print('Current notification permission status: $status');

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        // Request permission
        final newStatus = await Permission.notification.request();
        print('Permission after request: $newStatus');
        return newStatus.isGranted;
      }

      if (status.isPermanentlyDenied) {
        // Open app settings
        print('Notification permission permanently denied, opening settings');
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Request multiple permissions at once
  Future<Map<Permission, bool>> requestMultiplePermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.notification,
        Permission.location,
        Permission.locationWhenInUse,
      ].request();

      Map<Permission, bool> results = {};
      statuses.forEach((permission, status) {
        results[permission] = status.isGranted;
        print('Permission $permission: $status');
      });

      return results;
    } catch (e) {
      print('Error requesting multiple permissions: $e');
      return {};
    }
  }

  /// Show notification permission rationale
  String getNotificationPermissionRationale() {
    return 'Enable notifications to receive delivery updates, order confirmations, and important alerts in real-time.';
  }

  /// Show location permission rationale  
  String getLocationPermissionRationale() {
    return 'Enable location access to show your real-time position on the map and track deliveries accurately.';
  }

  /// Get permission status details
  Future<String> getNotificationPermissionStatusText() async {
    try {
      final status = await Permission.notification.status;
      
      switch (status) {
        case PermissionStatus.granted:
          return 'Notifications enabled';
        case PermissionStatus.denied:
          return 'Notifications disabled - tap to enable';
        case PermissionStatus.permanentlyDenied:
          return 'Notifications blocked - change in Settings';
        case PermissionStatus.restricted:
          return 'Notifications restricted by system';
        case PermissionStatus.limited:
          return 'Limited notification access';
        default:
          return 'Unknown notification status';
      }
    } catch (e) {
      return 'Error checking notifications';
    }
  }

  /// Check all required permissions
  Future<Map<String, bool>> checkAllPermissions() async {
    try {
      final notificationStatus = await Permission.notification.status;
      final locationStatus = await Permission.location.status;
      
      return {
        'notification': notificationStatus.isGranted,
        'location': locationStatus.isGranted,
      };
    } catch (e) {
      print('Error checking permissions: $e');
      return {
        'notification': false,
        'location': false,
      };
    }
  }
}