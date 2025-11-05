import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:razinshop_rider/services/location_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_controller.g.dart';

@riverpod
class CurrentLocation extends _$CurrentLocation {
  StreamSubscription<Position>? _locationSubscription;

  @override
  Position? build() {
    // Start listening to location updates when the provider is created
    _startLocationTracking();
    
    // Cleanup when the provider is disposed
    ref.onDispose(() {
      _locationSubscription?.cancel();
    });
    
    return null;
  }

  /// Start tracking location updates
  void _startLocationTracking() async {
    final locationService = ref.read(locationServiceProvider);
    
    // Get initial position
    final initialPosition = await locationService.getCurrentLocation();
    if (initialPosition != null) {
      state = initialPosition;
    }

    // Start listening to location stream
    _locationSubscription = locationService.getLocationStream().listen(
      (Position position) {
        state = position;
        print('Location updated: ${position.latitude}, ${position.longitude}');
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  /// Manually update location
  Future<void> updateLocation() async {
    final locationService = ref.read(locationServiceProvider);
    final position = await locationService.getCurrentLocation();
    if (position != null) {
      state = position;
    }
  }

  /// Stop location tracking
  void stopTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Resume location tracking
  void resumeTracking() {
    if (_locationSubscription == null) {
      _startLocationTracking();
    }
  }
}

@riverpod
class LocationPermission extends _$LocationPermission {
  @override
  bool build() {
    _checkPermission();
    return false;
  }

  Future<void> _checkPermission() async {
    final locationService = ref.read(locationServiceProvider);
    final hasPermission = await locationService.isLocationEnabled();
    state = hasPermission;
  }

  Future<bool> requestPermission() async {
    final locationService = ref.read(locationServiceProvider);
    final granted = await locationService.requestLocationPermission();
    state = granted;
    return granted;
  }
}

/// Provider for tracking delivery status
@riverpod
class DeliveryTracking extends _$DeliveryTracking {
  @override
  DeliveryTrackingState build() {
    return const DeliveryTrackingState();
  }

  /// Start delivery tracking for an order
  void startDelivery({
    required double pickupLat,
    required double pickupLng,
    required double deliveryLat,
    required double deliveryLng,
    required String orderId,
  }) {
    state = state.copyWith(
      isTracking: true,
      orderId: orderId,
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      deliveryLatitude: deliveryLat,
      deliveryLongitude: deliveryLng,
      status: DeliveryStatus.goingToPickup,
    );
  }

  /// Update delivery status based on current location
  void updateDeliveryStatus(Position currentPosition) {
    if (!state.isTracking) return;

    final locationService = ref.read(locationServiceProvider);
    
    switch (state.status) {
      case DeliveryStatus.idle:
        // No active delivery - nothing to update
        break;
      case DeliveryStatus.goingToPickup:
        // Check if rider is near pickup location
        final distanceToPickup = locationService.calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          state.pickupLatitude,
          state.pickupLongitude,
        );
        
        if (distanceToPickup <= 50) { // Within 50 meters of pickup
          state = state.copyWith(
            status: DeliveryStatus.atPickupLocation,
            distanceToPickup: distanceToPickup,
          );
        } else {
          state = state.copyWith(distanceToPickup: distanceToPickup);
        }
        break;

      case DeliveryStatus.goingToDelivery:
        // Check if rider is near delivery location
        final distanceToDelivery = locationService.calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          state.deliveryLatitude,
          state.deliveryLongitude,
        );
        
        if (distanceToDelivery <= 50) { // Within 50 meters of delivery
          state = state.copyWith(
            status: DeliveryStatus.atDeliveryLocation,
            distanceToDelivery: distanceToDelivery,
          );
        } else {
          state = state.copyWith(distanceToDelivery: distanceToDelivery);
        }
        break;

      case DeliveryStatus.atPickupLocation:
      case DeliveryStatus.atDeliveryLocation:
        // Update distances even when at location
        final distanceToPickup = locationService.calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          state.pickupLatitude,
          state.pickupLongitude,
        );
        final distanceToDelivery = locationService.calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          state.deliveryLatitude,
          state.deliveryLongitude,
        );
        
        state = state.copyWith(
          distanceToPickup: distanceToPickup,
          distanceToDelivery: distanceToDelivery,
        );
        break;
      case DeliveryStatus.delivered:
        // Delivery finished - stop tracking or keep final distances
        break;
    }
  }

  /// Mark pickup as completed
  void completePickup() {
    state = state.copyWith(status: DeliveryStatus.goingToDelivery);
  }

  /// Mark delivery as completed
  void completeDelivery() {
    state = state.copyWith(
      status: DeliveryStatus.delivered,
      isTracking: false,
    );
  }

  /// Stop delivery tracking
  void stopDelivery() {
    state = const DeliveryTrackingState();
  }
}

/// Delivery tracking state
class DeliveryTrackingState {
  final bool isTracking;
  final String orderId;
  final double pickupLatitude;
  final double pickupLongitude;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final DeliveryStatus status;
  final double distanceToPickup;
  final double distanceToDelivery;

  const DeliveryTrackingState({
    this.isTracking = false,
    this.orderId = '',
    this.pickupLatitude = 0.0,
    this.pickupLongitude = 0.0,
    this.deliveryLatitude = 0.0,
    this.deliveryLongitude = 0.0,
    this.status = DeliveryStatus.idle,
    this.distanceToPickup = 0.0,
    this.distanceToDelivery = 0.0,
  });

  DeliveryTrackingState copyWith({
    bool? isTracking,
    String? orderId,
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
    DeliveryStatus? status,
    double? distanceToPickup,
    double? distanceToDelivery,
  }) {
    return DeliveryTrackingState(
      isTracking: isTracking ?? this.isTracking,
      orderId: orderId ?? this.orderId,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      status: status ?? this.status,
      distanceToPickup: distanceToPickup ?? this.distanceToPickup,
      distanceToDelivery: distanceToDelivery ?? this.distanceToDelivery,
    );
  }
}

/// Delivery status enum
enum DeliveryStatus {
  idle,
  goingToPickup,
  atPickupLocation,
  goingToDelivery,
  atDeliveryLocation,
  delivered,
}
