import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:razinshop_rider/controllers/misc/permission_controller.dart';
import 'package:razinshop_rider/controllers/location_controller/location_controller.dart';
import 'package:razinshop_rider/services/app_permission_service.dart';

class PermissionRequestDialog extends ConsumerWidget {
  final bool showLocation;
  final bool showNotification;
  final VoidCallback? onComplete;

  const PermissionRequestDialog({
    Key? key,
    this.showLocation = true,
    this.showNotification = true,
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(appPermissionsProvider);
    final permissionService = ref.read(appPermissionServiceProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('App Permissions'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Total Ride needs these permissions to provide the best delivery experience:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            if (showLocation) ...[
              _PermissionTile(
                icon: Icons.location_on,
                title: 'Location Access',
                description: permissionService.getLocationPermissionRationale(),
                isGranted: permissions['location'] ?? false,
                onTap: () async {
                  final granted = await ref
                      .read(locationPermissionProvider.notifier)
                      .requestPermission();
                  if (granted) {
                    onPressed: () async {
                    await ref.read(appPermissionsProvider.notifier).requestAllPermissions();
                  },
                    ref.read(currentLocationProvider.notifier).updateLocation();
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            
            if (showNotification) ...[
              _PermissionTile(
                icon: Icons.notifications,
                title: 'Notifications',
                description: permissionService.getNotificationPermissionRationale(),
                isGranted: permissions['notification'] ?? false,
                onTap: () async {
                  final granted = await ref
                      .read(appPermissionsProvider.notifier)
                      .requestNotificationPermission();
                  if (!granted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enable notifications in Settings'),
                        action: SnackBarAction(
                          label: 'Settings',
                          onPressed: () => openAppSettings(),
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            
            const Divider(),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can change these permissions anytime in Settings',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onComplete?.call();
          },
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref.read(appPermissionsProvider.notifier).requestAllPermissions();
            Navigator.of(context).pop();
            onComplete?.call();
          },
          child: const Text('Allow All'),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isGranted ? Colors.green : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isGranted ? Colors.green.shade50 : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isGranted ? Colors.green : Colors.grey,
        ),
        title: Row(
          children: [
            Text(title),
            const SizedBox(width: 8),
            if (isGranted)
              Icon(Icons.check_circle, color: Colors.green, size: 16),
          ],
        ),
        subtitle: Text(
          description,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: isGranted
            ? null
            : TextButton(
                onPressed: onTap,
                child: const Text('Allow'),
              ),
        onTap: isGranted ? null : onTap,
      ),
    );
  }
}

// Helper function to show permission dialog
void showPermissionDialog(
  BuildContext context, {
  bool showLocation = true,
  bool showNotification = true,
  VoidCallback? onComplete,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PermissionRequestDialog(
      showLocation: showLocation,
      showNotification: showNotification,
      onComplete: onComplete,
    ),
  );
}
