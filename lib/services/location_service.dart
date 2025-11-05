import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_service.g.dart';

@riverpod
LocationService locationService(LocationServiceRef ref) {
  return LocationService(ref);
}

class LocationService {
  final Ref ref;
  LocationService(this.ref);

  /// Check if location services are enabled and permissions are granted
  Future<bool> isLocationEnabled() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Try to open location settings
        bool opened = await Geolocator.openLocationSettings();
        if (!opened) {
          print('Could not open location settings');
          return false;
        }
        // Check again after user potentially enables location
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('Current location permission: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');
        
        if (permission == LocationPermission.denied) {
          print('Location permission denied by user');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission denied forever, opening app settings');
        // Use permission_handler to open app settings
        await Permission.location.request();
        if (await Permission.location.isPermanentlyDenied) {
          await openAppSettings();
        }
        return false;
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        print('Location permission granted: $permission');
        return true;
      }

      return false;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Get current position
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await isLocationEnabled();
      if (!hasPermission) {
        print('Location not enabled, requesting permission...');
        hasPermission = await requestLocationPermission();
        if (!hasPermission) {
          print('Permission denied, cannot get location');
          return null;
        }
      }

      print('Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );

      print('Got position: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('Error getting location: $e');
      // Try with lower accuracy as fallback
      try {
        print('Trying with medium accuracy...');
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
        print('Got fallback position: ${position.latitude}, ${position.longitude}');
        return position;
      } catch (e2) {
        print('Fallback also failed: $e2');
        return null;
      }
    }
  }

  /// Get location stream for real-time tracking
  Stream<Position> getLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Calculate distance between two points
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Calculate bearing (direction) between two points
  double calculateBearing(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if rider is within delivery geofence (e.g., 100 meters)
  bool isWithinDeliveryRange(
    double riderLat,
    double riderLng,
    double destinationLat,
    double destinationLng, {
    double rangeInMeters = 100.0,
  }) {
    double distance = calculateDistance(
      riderLat,
      riderLng,
      destinationLat,
      destinationLng,
    );
    return distance <= rangeInMeters;
  }
}
