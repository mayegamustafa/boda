import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:razinshop_rider/controllers/location_controller/location_controller.dart';
import 'package:razinshop_rider/services/location_service.dart';

// Mock location service for testing
class MockLocationService implements LocationService {
  Position? _mockPosition;
  bool _mockPermissionGranted = true;
  
  void setMockPosition(Position position) {
    _mockPosition = position;
  }
  
  void setMockPermission(bool granted) {
    _mockPermissionGranted = granted;
  }
  
  @override
  Ref get ref => throw UnimplementedError('Mock ref not needed');
  
  @override
  Future<bool> isLocationEnabled() async {
    return _mockPermissionGranted;
  }
  
  @override
  Future<bool> requestLocationPermission() async {
    return _mockPermissionGranted;
  }
  
  @override
  Future<Position?> getCurrentLocation() async {
    if (!_mockPermissionGranted) return null;
    return _mockPosition ?? Position(
      latitude: 23.7686089,
      longitude: 90.3547867,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
  
  @override
  Stream<Position> getLocationStream() {
    if (!_mockPermissionGranted) return Stream.empty();
    return Stream.periodic(
      const Duration(seconds: 1),
      (count) => Position(
        latitude: 23.7686089 + (count * 0.0001),
        longitude: 90.3547867 + (count * 0.0001),
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ),
    );
  }
  
  @override
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    // Simple mock distance calculation (not accurate, just for testing)
    return 100.0; // Mock 100 meters distance
  }
  
  @override
  double calculateBearing(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return 0.0; // Mock bearing
  }
  
  @override
  bool isWithinDeliveryRange(
    double riderLat,
    double riderLng,
    double destinationLat,
    double destinationLng, {
    double rangeInMeters = 100.0,
  }) {
    return calculateDistance(riderLat, riderLng, destinationLat, destinationLng) <= rangeInMeters;
  }
}

void main() {
  group('Location Controller Tests', () {
    late ProviderContainer container;
    late MockLocationService mockLocationService;
    
    setUp(() {
      mockLocationService = MockLocationService();
      container = ProviderContainer(
        overrides: [
          locationServiceProvider.overrideWithValue(mockLocationService),
        ],
      );
    });
    
    tearDown(() {
      container.dispose();
    });
    
    test('should initialize with null position', () {
      final currentLocation = container.read(currentLocationProvider);
      expect(currentLocation, isNull);
    });
    
    test('should grant permission when requested', () async {
      mockLocationService.setMockPermission(true);
      
      final permissionNotifier = container.read(locationPermissionProvider.notifier);
      final granted = await permissionNotifier.requestPermission();
      
      expect(granted, isTrue);
      expect(container.read(locationPermissionProvider), isTrue);
    });
    
    test('should deny permission when not granted', () async {
      mockLocationService.setMockPermission(false);
      
      final permissionNotifier = container.read(locationPermissionProvider.notifier);
      final granted = await permissionNotifier.requestPermission();
      
      expect(granted, isFalse);
      expect(container.read(locationPermissionProvider), isFalse);
    });
    
    test('should update location manually', () async {
      final mockPosition = Position(
        latitude: 24.0,
        longitude: 91.0,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
      
      mockLocationService.setMockPosition(mockPosition);
      mockLocationService.setMockPermission(true);
      
      final locationNotifier = container.read(currentLocationProvider.notifier);
      await locationNotifier.updateLocation();
      
      final currentLocation = container.read(currentLocationProvider);
      expect(currentLocation?.latitude, equals(24.0));
      expect(currentLocation?.longitude, equals(91.0));
    });
    
    group('Delivery Tracking Tests', () {
      test('should initialize with idle state', () {
        final deliveryState = container.read(deliveryTrackingProvider);
        
        expect(deliveryState.isTracking, isFalse);
        expect(deliveryState.status, equals(DeliveryStatus.idle));
        expect(deliveryState.orderId, isEmpty);
      });
      
      test('should start delivery tracking', () {
        final deliveryNotifier = container.read(deliveryTrackingProvider.notifier);
        
        deliveryNotifier.startDelivery(
          pickupLat: 23.7686089,
          pickupLng: 90.3547867,
          deliveryLat: 23.8103,
          deliveryLng: 90.4125,
          orderId: '123',
        );
        
        final deliveryState = container.read(deliveryTrackingProvider);
        
        expect(deliveryState.isTracking, isTrue);
        expect(deliveryState.status, equals(DeliveryStatus.goingToPickup));
        expect(deliveryState.orderId, equals('123'));
        expect(deliveryState.pickupLatitude, equals(23.7686089));
        expect(deliveryState.deliveryLatitude, equals(23.8103));
      });
      
      test('should complete pickup and move to delivery', () {
        final deliveryNotifier = container.read(deliveryTrackingProvider.notifier);
        
        // Start delivery
        deliveryNotifier.startDelivery(
          pickupLat: 23.7686089,
          pickupLng: 90.3547867,
          deliveryLat: 23.8103,
          deliveryLng: 90.4125,
          orderId: '123',
        );
        
        // Complete pickup
        deliveryNotifier.completePickup();
        
        final deliveryState = container.read(deliveryTrackingProvider);
        expect(deliveryState.status, equals(DeliveryStatus.goingToDelivery));
      });
      
      test('should complete delivery and stop tracking', () {
        final deliveryNotifier = container.read(deliveryTrackingProvider.notifier);
        
        // Start delivery
        deliveryNotifier.startDelivery(
          pickupLat: 23.7686089,
          pickupLng: 90.3547867,
          deliveryLat: 23.8103,
          deliveryLng: 90.4125,
          orderId: '123',
        );
        
        // Complete delivery
        deliveryNotifier.completeDelivery();
        
        final deliveryState = container.read(deliveryTrackingProvider);
        expect(deliveryState.status, equals(DeliveryStatus.delivered));
        expect(deliveryState.isTracking, isFalse);
      });
      
      test('should stop delivery tracking', () {
        final deliveryNotifier = container.read(deliveryTrackingProvider.notifier);
        
        // Start delivery
        deliveryNotifier.startDelivery(
          pickupLat: 23.7686089,
          pickupLng: 90.3547867,
          deliveryLat: 23.8103,
          deliveryLng: 90.4125,
          orderId: '123',
        );
        
        // Stop delivery
        deliveryNotifier.stopDelivery();
        
        final deliveryState = container.read(deliveryTrackingProvider);
        expect(deliveryState.isTracking, isFalse);
        expect(deliveryState.status, equals(DeliveryStatus.idle));
        expect(deliveryState.orderId, isEmpty);
      });
    });
  });
}