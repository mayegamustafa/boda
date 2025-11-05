// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentLocationHash() => r'975fa2bd1a87b360f93519de5d3944919a67c175';

/// See also [CurrentLocation].
@ProviderFor(CurrentLocation)
final currentLocationProvider =
    AutoDisposeNotifierProvider<CurrentLocation, Position?>.internal(
  CurrentLocation.new,
  name: r'currentLocationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentLocationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentLocation = AutoDisposeNotifier<Position?>;
String _$locationPermissionHash() =>
    r'2447b1d728922a2dda0d7f25fb6f9ea8fa10bcf3';

/// See also [LocationPermission].
@ProviderFor(LocationPermission)
final locationPermissionProvider =
    AutoDisposeNotifierProvider<LocationPermission, bool>.internal(
  LocationPermission.new,
  name: r'locationPermissionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$locationPermissionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LocationPermission = AutoDisposeNotifier<bool>;
String _$deliveryTrackingHash() => r'4e4e830455225aa229afafa80cedb0cbf02ee739';

/// Provider for tracking delivery status
///
/// Copied from [DeliveryTracking].
@ProviderFor(DeliveryTracking)
final deliveryTrackingProvider = AutoDisposeNotifierProvider<DeliveryTracking,
    DeliveryTrackingState>.internal(
  DeliveryTracking.new,
  name: r'deliveryTrackingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deliveryTrackingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DeliveryTracking = AutoDisposeNotifier<DeliveryTrackingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
