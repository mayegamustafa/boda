import 'package:razinshop_rider/models/notification_model.dart';
import 'package:razinshop_rider/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_controller.g.dart';

@riverpod
class NotificationController extends _$NotificationController {
  @override
  FutureOr<List<Notification>> build() async {
    return await ref
        .read(notificationServiceProvider)
        .getNotifications()
        .then((value) {
      if (value.statusCode == 200) {
        List<dynamic> dataList = value.data['data']['notification'] ?? [];
        return dataList
            .map((e) => Notification.fromMap(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    });
  }

  void isReadNotification(Notification notification) {
    final data = state.value ?? [];
    final index = data.indexWhere((element) => element.id == notification.id);
    if (index != -1 && data[index].isRead!) {
      return;
    }
    if (index != -1) {
      data[index] = notification..isRead = true;
      state = AsyncValue.data(data);
    }
  }
}
