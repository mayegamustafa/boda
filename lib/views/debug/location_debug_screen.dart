import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razinshop_rider/controllers/location_controller/location_controller.dart';
import 'package:razinshop_rider/controllers/misc/permission_controller.dart';
import 'package:razinshop_rider/services/location_service.dart';
import 'package:razinshop_rider/components/permission_request_dialog.dart';

class LocationDebugScreen extends ConsumerWidget {
  const LocationDebugScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = ref.watch(currentLocationProvider);
    final locationPermission = ref.watch(locationPermissionProvider);
    final appPermissions = ref.watch(appPermissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Debug'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permission Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Location Permission: ${locationPermission ? "✅ Granted" : "❌ Denied"}'),
                    Text('Notification Permission: ${appPermissions["notification"] ?? false ? "✅ Granted" : "❌ Denied"}'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final granted = await ref
                                .read(locationPermissionProvider.notifier)
                                .requestPermission();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(granted ? 'Permission granted!' : 'Permission denied'),
                                backgroundColor: granted ? Colors.green : Colors.red,
                              ),
                            );
                          },
                          child: const Text('Request Location'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => showPermissionDialog(context),
                          child: const Text('Show Dialog'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Location',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (currentLocation != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Latitude: ${currentLocation.latitude}'),
                          Text('Longitude: ${currentLocation.longitude}'),
                          Text('Accuracy: ${currentLocation.accuracy}m'),
                          Text('Timestamp: ${currentLocation.timestamp}'),
                        ],
                      )
                    else
                      const Text('No location data'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await ref.read(currentLocationProvider.notifier).updateLocation();
                          },
                          child: const Text('Get Location'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final locationService = ref.read(locationServiceProvider);
                            final position = await locationService.getCurrentLocation();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(position != null 
                                  ? 'Got location: ${position.latitude}, ${position.longitude}'
                                  : 'Failed to get location'
                                ),
                              ),
                            );
                          },
                          child: const Text('Direct Test'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Service Test',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final locationService = ref.read(locationServiceProvider);
                        
                        // Test step by step
                        print('=== LOCATION SERVICE TEST ===');
                        
                        final enabled = await locationService.isLocationEnabled();
                        print('Location enabled: $enabled');
                        
                        if (!enabled) {
                          final granted = await locationService.requestLocationPermission();
                          print('Permission granted: $granted');
                        }
                        
                        final position = await locationService.getCurrentLocation();
                        print('Position: $position');
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Check console for detailed logs'),
                          ),
                        );
                      },
                      child: const Text('Run Full Test'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}