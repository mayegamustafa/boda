// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationPermissionHash() =>
    r'c8b2b502ec3393fcdb9f15225cd30cbc8339df53';

/// See also [NotificationPermission].
@ProviderFor(NotificationPermission)
final notificationPermissionProvider =
    AutoDisposeNotifierProvider<NotificationPermission, bool>.internal(
  NotificationPermission.new,
  name: r'notificationPermissionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationPermissionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationPermission = AutoDisposeNotifier<bool>;
String _$appPermissionsHash() => r'84663553fc3a8bb33d756aa1177b54fcd105bead';

/// See also [AppPermissions].
@ProviderFor(AppPermissions)
final appPermissionsProvider =
    AutoDisposeNotifierProvider<AppPermissions, Map<String, bool>>.internal(
  AppPermissions.new,
  name: r'appPermissionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appPermissionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppPermissions = AutoDisposeNotifier<Map<String, bool>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
