import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:razinshop_rider/services/app_permission_service.dart';

part 'permission_controller.g.dart';

@riverpod
class NotificationPermission extends _$NotificationPermission {
  @override
  bool build() {
    _checkPermission();
    return false;
  }

  Future<void> _checkPermission() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final hasPermission = await permissionService.isNotificationEnabled();
    state = hasPermission;
  }

  Future<bool> requestPermission() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final granted = await permissionService.requestNotificationPermission();
    state = granted;
    return granted;
  }
}

@riverpod
class AppPermissions extends _$AppPermissions {
  @override
  Map<String, bool> build() {
    _checkAllPermissions();
    return {
      'notification': false,
      'location': false,
    };
  }

  Future<void> _checkAllPermissions() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final permissions = await permissionService.checkAllPermissions();
    state = permissions;
  }

  Future<void> requestAllPermissions() async {
    final permissionService = ref.read(appPermissionServiceProvider);
    final results = await permissionService.requestMultiplePermissions();
    
    Map<String, bool> newState = {};
    results.forEach((permission, granted) {
      switch (permission.toString()) {
        case 'Permission.notification':
          newState['notification'] = granted;
          break;
        case 'Permission.location':
        case 'Permission.locationWhenInUse':
          newState['location'] = granted;
          break;
      }
    });
    
    state = {...state, ...newState};
  }

  Future<bool> requestNotificationPermission() async {
    final notificationNotifier = ref.read(notificationPermissionProvider.notifier);
    final granted = await notificationNotifier.requestPermission();
    
    state = {...state, 'notification': granted};
    return granted;
  }
}