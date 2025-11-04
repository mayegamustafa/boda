import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razinshop_rider/config/app_constants.dart';
import 'package:razinshop_rider/utils/api_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'notification_service.g.dart';

@riverpod
NotificationService notificationService(NotificationServiceRef ref) {
  return NotificationService(ref);
}

abstract class NotificationRepo {
  Future<Response> getNotifications();
}

class NotificationService implements NotificationRepo {
  final Ref ref;
  NotificationService(this.ref);

  @override
  Future<Response> getNotifications() async {
    return ref.read(apiClientProvider).get(AppConstants.notification);
  }
}
