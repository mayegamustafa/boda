// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:razinshop_rider/utils/extensions.dart';
import 'package:razinshop_rider/controllers/location_controller/location_controller.dart';


class GoogleMapView extends ConsumerStatefulWidget {
  final double? latitude;
  final double? longitude;
  final String pinIcon;
  final bool showCurrentLocation;
  final bool trackDelivery;
  final String? orderId;
  
  const GoogleMapView({
    Key? key,
    this.latitude,
    this.longitude,
    required this.pinIcon,
    this.showCurrentLocation = false,
    this.trackDelivery = false,
    this.orderId,
  }) : super(key: key);

  @override
  ConsumerState<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends ConsumerState<GoogleMapView> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  late CameraPosition _kGooglePlex;
  BitmapDescriptor? _destinationMarker;
  BitmapDescriptor? _riderMarker;
  BitmapDescriptor? _pickupMarker;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadMarkers();
  }

  void _initializeMap() {
    // Set default camera position
    double lat = widget.latitude ?? 23.7686089;
    double lng = widget.longitude ?? 90.3547867;
    
    _kGooglePlex = CameraPosition(
      target: LatLng(lat, lng),
      zoom: 16.4746,
    );
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<void> _loadMarkers() async {
    try {
      // Load destination marker
      final Uint8List destinationIcon = await getBytesFromAsset(widget.pinIcon, 80);
      _destinationMarker = BitmapDescriptor.fromBytes(destinationIcon);
    } catch (e) {
      print('Could not load destination marker: $e');
      _destinationMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    
    try {
      // Try to load rider marker, fallback to default blue
      _riderMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    } catch (e) {
      print('Could not load rider marker: $e');
      _riderMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
    
    try {
      // Try to load pickup marker, fallback to default green
      _pickupMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } catch (e) {
      print('Could not load pickup marker: $e');
      _pickupMarker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }

    if (mounted) {
      setState(() {});
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    final currentLocation = ref.watch(currentLocationProvider);
    final deliveryTracking = ref.watch(deliveryTrackingProvider);
    
    Set<Marker> newMarkers = {};
    
    print('Updating markers - Current location: $currentLocation');
    print('Show current location: ${widget.showCurrentLocation}');
    
    // Add current location marker FIRST and prominently if enabled and available
    if (widget.showCurrentLocation && currentLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: LatLng(currentLocation.latitude, currentLocation.longitude),
          icon: _riderMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: 'Your Current Location',
            snippet: 'Lat: ${currentLocation.latitude.toStringAsFixed(4)}, Lng: ${currentLocation.longitude.toStringAsFixed(4)}',
          ),
        ),
      );
      print('Added current location marker at: ${currentLocation.latitude}, ${currentLocation.longitude}');
    }
    
    // Add destination marker if coordinates provided (but make it secondary)
    if (widget.latitude != null && widget.longitude != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.latitude!, widget.longitude!),
          icon: _destinationMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }
    
    // Add delivery tracking markers if enabled
    if (widget.trackDelivery && deliveryTracking.isTracking) {
      // Pickup marker
      newMarkers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(deliveryTracking.pickupLatitude, deliveryTracking.pickupLongitude),
          icon: _pickupMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 1),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
      );
      
      // Delivery marker
      newMarkers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: LatLng(deliveryTracking.deliveryLatitude, deliveryTracking.deliveryLongitude),
          icon: _destinationMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 1),
          infoWindow: const InfoWindow(title: 'Delivery Location'),
        ),
      );
    }
    
    setState(() {
      markers = newMarkers;
    });
    
    // Update camera to show all markers
    _fitMarkersToCamera();
  }

  void _fitMarkersToCamera() async {
    if (markers.isEmpty) return;
    
    final controller = await _controller.future;
    final currentLocation = ref.read(currentLocationProvider);
    
    // If we have current location, prioritize it
    if (widget.showCurrentLocation && currentLocation != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(currentLocation.latitude, currentLocation.longitude),
            zoom: 17.0, // Higher zoom for current location
          ),
        ),
      );
      print('Centered camera on current location: ${currentLocation.latitude}, ${currentLocation.longitude}');
      return;
    }
    
    if (markers.length == 1) {
      // If only one marker, center on it
      final marker = markers.first;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: marker.position,
            zoom: 16.0,
          ),
        ),
      );
    } else {
      // If multiple markers, fit them all in view
      double minLat = markers.first.position.latitude;
      double maxLat = markers.first.position.latitude;
      double minLng = markers.first.position.longitude;
      double maxLng = markers.first.position.longitude;
      
      for (final marker in markers) {
        minLat = marker.position.latitude < minLat ? marker.position.latitude : minLat;
        maxLat = marker.position.latitude > maxLat ? marker.position.latitude : maxLat;
        minLng = marker.position.longitude < minLng ? marker.position.longitude : minLng;
        maxLng = marker.position.longitude > maxLng ? marker.position.longitude : maxLng;
      }
      
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100.0, // padding
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.future.then((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to location and delivery tracking changes
    ref.listen<Position?>(currentLocationProvider, (previous, next) {
      if (next != null) {
        _updateMarkers();
      }
    });
    
    ref.listen<DeliveryTrackingState>(deliveryTrackingProvider, (previous, next) {
      _updateMarkers();
    });

    if (_destinationMarker == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: widget.showCurrentLocation,
          mapType: context.isDark ? MapType.satellite : MapType.terrain,
          initialCameraPosition: _kGooglePlex,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
            _updateMarkers(); // Update markers when map is ready
          },
          markers: markers,
          polylines: polylines,
        ),
        
        // Location permission request overlay
        Consumer(
          builder: (context, ref, child) {
            final hasPermission = ref.watch(locationPermissionProvider);
            final currentLocation = ref.watch(currentLocationProvider);
            
            if (!hasPermission && widget.showCurrentLocation) {
              return Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 48, color: Colors.blue),
                        const SizedBox(height: 8),
                        const Text(
                          'Enable Location Access',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Allow location access to show your real-time position on the map and track deliveries.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Hide the overlay but don't request permission
                                  ref.read(locationPermissionProvider.notifier).state = true;
                                },
                                child: const Text('Skip'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  print('Permission button pressed');
                                  final granted = await ref
                                      .read(locationPermissionProvider.notifier)
                                      .requestPermission();
                                  print('Permission granted: $granted');
                                  if (granted) {
                                    // Trigger location update
                                    await ref.read(currentLocationProvider.notifier).updateLocation();
                                    print('Location update triggered');
                                  } else {
                                    // Show error message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Location permission denied. You can enable it in Settings.'),
                                        action: SnackBarAction(
                                          label: 'Settings',
                                          onPressed: openAppSettings,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Allow Location'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else if (widget.showCurrentLocation && currentLocation == null) {
              // Show loading state when permission granted but no location yet
              return Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircularProgressIndicator(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Getting your location...'),
                              Text(
                                'Make sure GPS is enabled',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            
            return const SizedBox.shrink();
          },
        ),
        
        // Delivery status overlay
        if (widget.trackDelivery)
          Consumer(
            builder: (context, ref, child) {
              final deliveryState = ref.watch(deliveryTrackingProvider);
              
              if (!deliveryState.isTracking) return const SizedBox.shrink();
              
              return Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order: ${deliveryState.orderId}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Status: ${_getStatusText(deliveryState.status)}'),
                        if (deliveryState.distanceToPickup > 0)
                          Text('Distance to Pickup: ${deliveryState.distanceToPickup.toStringAsFixed(0)}m'),
                        if (deliveryState.distanceToDelivery > 0)
                          Text('Distance to Delivery: ${deliveryState.distanceToDelivery.toStringAsFixed(0)}m'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
  
  String _getStatusText(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.idle:
        return 'Ready';
      case DeliveryStatus.goingToPickup:
        return 'Going to Pickup';
      case DeliveryStatus.atPickupLocation:
        return 'At Pickup Location';
      case DeliveryStatus.goingToDelivery:
        return 'Going to Delivery';
      case DeliveryStatus.atDeliveryLocation:
        return 'At Delivery Location';
      case DeliveryStatus.delivered:
        return 'Delivered';
    }
  }
}
