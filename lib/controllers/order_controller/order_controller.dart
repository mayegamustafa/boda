import 'package:razinshop_rider/controllers/misc/providers.dart';
import 'package:razinshop_rider/controllers/order_controller/order_state.dart';
import 'package:razinshop_rider/models/order_details_model/order_details_model.dart';
import 'package:razinshop_rider/models/order_model/order.dart';
import 'package:razinshop_rider/services/order_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'order_controller.g.dart';

@riverpod
class OrderList extends _$OrderList {
  @override
  Future<OrderState> build() async {
    return await getOrders(); // Initially load the data
  }

  Future<OrderState> getOrders({int page = 1, int perPage = 10}) async {
    state = const AsyncLoading(); // Set loading state

    try {
      // Fetching data from API
      final response = await ref
          .read(orderServiceProvider)
          .getOrders(page: page, perPage: perPage);

      // Extracting orders as List<dynamic>
      final List<dynamic> data = response.data['data']['orders'];

      // Convert List<dynamic> to List<Order>
      // Make sure to explicitly cast the data to List<Order>
      final List<Order> orders =
          data.map<Order>((e) {
            return Order.fromMap(e as Map<String, dynamic>); // Explicit casting
          }).toList();

      // Fetching other details from the response
      int todoOrder = response.data['data']['to_do_order'];
      int completedOrder = response.data['data']['completed_order'];
      int total = response.data['data']['total'];

      // Ensure that the state.value is safely accessed and is of the correct type
      List<Order> existingOrders = state.value?.orders ?? [];

      // If it's the first page, reset the list; otherwise, append new orders
      final updatedOrders = page == 1 ? orders : [...existingOrders, ...orders];

      state = AsyncData(
        OrderState(
          todoOrder: todoOrder,
          completedOrder: completedOrder,
          total: total,
          orders: updatedOrders, // Ensure it's List<Order>
        ),
      );

      // Return the updated OrderState
      return OrderState(
        todoOrder: todoOrder,
        completedOrder: completedOrder,
        total: total,
        orders: updatedOrders, // Ensure it's List<Order>
      );
    } catch (error) {
      state = AsyncError(error, StackTrace.current);
      rethrow;
    }
  }

  // Refresh method for pull-to-refresh functionality
  Future<void> refreshOrders({int page = 1, int perPage = 10}) async {
    state = const AsyncLoading(); // Set loading state when refreshing
    var data = await getOrders(
      page: page,
      perPage: perPage,
    ); // Fetch fresh data
    state = AsyncData(data); // Set the new data
  }
}

@riverpod
class OrderDetails extends _$OrderDetails {
  @override
  FutureOr<OrderDetailsModel> build(int arg) async {
    return await ref.read(orderServiceProvider).getOrderDetails(arg).then((
      value,
    ) async {
      var data = OrderDetailsModel.fromMap(value.data);
      ref.read(buttonText.notifier).state = data.data?.order?.orderStatus ?? '';
      return data;
    });
  }
}

@riverpod
class OrderStatusUpdate extends _$OrderStatusUpdate {
  @override
  bool build() {
    return false;
  }

  Future<OrderDetailsModel> updateOrderStatus(int orderId) async {
    state = true;
    final response = await ref
        .read(orderServiceProvider)
        .updateOrderStatus(orderId: orderId);
    state = false;
    return OrderDetailsModel.fromMap(response.data);
  }
}

@riverpod
class OrderHistory extends _$OrderHistory {
  List<Order> orderList = [];
  @override
  FutureOr<OrderHistoryState> build() async {
    print("Filter: ");
    final filter = ref.watch(orderHistoryFilterProvider);
    return await filterOrderHistory(filter);
  }

  Future<OrderHistoryState> filterOrderHistory(
    TodoListFilter filter, {
    int page = 1,
    perPage = 10,
  }) async {
    if (filter != TodoListFilter.all) {
      orderList = [];
    }
    switch (filter) {
      case TodoListFilter.all:
        final response = await ref
            .read(orderServiceProvider)
            .orderHistory(page: page, perPage: perPage);
        int total = response.data['data']['total'];
        orderList.addAll(_transformOrders(response.data['data']['orders']));
        return OrderHistoryState(
          allOrder: response.data['data']['all_orders'],
          toDeliver: response.data['data']['to_deliver'],
          delivered: response.data['data']['delivered'],
          total: total,
          orders: orderList,
        );

      case TodoListFilter.pending:
        final response = await ref
            .read(orderServiceProvider)
            .orderHistory(status: 'to_deliver');
        return OrderHistoryState(
          allOrder: response.data['data']['all_orders'],
          toDeliver: response.data['data']['to_deliver'],
          delivered: response.data['data']['delivered'],
          orders: _transformOrders(response.data['data']['orders']),
        );

      case TodoListFilter.delivered:
        final response = await ref
            .read(orderServiceProvider)
            .orderHistory(status: 'delivered');
        return OrderHistoryState(
          allOrder: response.data['data']['all_orders'],
          toDeliver: response.data['data']['to_deliver'],
          delivered: response.data['data']['delivered'],
          orders: _transformOrders(response.data['data']['orders']),
        );
    }
  }

  void refresh() async {
    state = const AsyncLoading();
    final filter = ref.read(orderHistoryFilterProvider);
    state = AsyncData(await filterOrderHistory(filter));
  }

  void searchOrderHistory(String query) async {
    state = const AsyncLoading();
    final response = await ref
        .read(orderServiceProvider)
        .orderHistory(query: query);
    final data = _transformOrders(response.data['data']['orders']);
    state = AsyncData(
      OrderHistoryState(allOrder: 0, toDeliver: 0, delivered: 0, orders: []),
    );
    state = AsyncData(
      OrderHistoryState(
        allOrder: response.data['data']['all_orders'],
        toDeliver: response.data['data']['to_deliver'],
        delivered: response.data['data']['delivered'],
        orders: data,
      ),
    );
  }

  void searchOrderHistoryByDate(String date) async {
    state = const AsyncLoading();
    final response = await ref
        .read(orderServiceProvider)
        .orderHistory(date: date);
    final data = _transformOrders(response.data['data']['orders']);
    state = AsyncData(
      OrderHistoryState(allOrder: 0, toDeliver: 0, delivered: 0, orders: []),
    );

    state = AsyncData(
      OrderHistoryState(
        allOrder: response.data['data']['all_orders'],
        toDeliver: response.data['data']['to_deliver'],
        delivered: response.data['data']['delivered'],
        orders: data,
      ),
    );
  }

  List<Order> _transformOrders(List<dynamic> orders) {
    return orders.map<Order>((order) => Order.fromMap(order)).toList();
  }
}
