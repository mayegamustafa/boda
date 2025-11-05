import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razinshop_rider/config/app_constants.dart';
import 'package:razinshop_rider/services/order_service.dart';
import 'package:razinshop_rider/utils/global_function.dart';

/// Simple polling-based order notification helper.
///
/// This service periodically polls the orders endpoint (every [interval])
/// and compares the todo count. When a new order arrives (todo count increases)
/// it will show an in-app snackbar and invalidate the orders provider so the
/// UI refreshes.
class OrderNotificationService {
  final Ref ref;
  Timer? _timer;
  int? _lastTodoCount;
  Duration interval;

  OrderNotificationService(this.ref, {this.interval = const Duration(seconds: 15)});

  void startOrderMonitoring() {
    // Cancel any existing timer
    stopOrderMonitoring();

    // seed last value from current provider if available
    try {
      final state = ref.read(orderListProvider);
      _lastTodoCount = state.whenOrNull(data: (data) => data.todoOrder) ?? _lastTodoCount;
    } catch (_) {}

    _timer = Timer.periodic(interval, (_) async {
      try {
        final response = await ref.read(orderServiceProvider).getOrders(page: 1, perPage: 10);
        final int todo = response.data['data']['to_do_order'] ?? 0;

        // If we had a previous count and it increased, notify user
        if (_lastTodoCount != null && todo > _lastTodoCount!) {
          GlobalFunction.showCustomSnackbar(
            message: 'New order assigned',
            isSuccess: true,
          );
          // refresh order list provider so UI picks up new orders
          ref.invalidate(orderListProvider);
        }

        _lastTodoCount = todo;
      } catch (e) {
        // silently ignore polling errors (they will be logged by request handler)
      }
    });
  }

  void stopOrderMonitoring() {
    _timer?.cancel();
    _timer = null;
  }
}

final orderNotificationServiceProvider = Provider((ref) {
  return OrderNotificationService(ref);
});
