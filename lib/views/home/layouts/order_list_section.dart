import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:razinshop_rider/config/app_color.dart';
import 'package:razinshop_rider/controllers/order_controller/order_controller.dart';
import 'package:razinshop_rider/views/home/components/order_card.dart';

class OrderListSection extends ConsumerStatefulWidget {
  const OrderListSection({super.key});

  @override
  ConsumerState<OrderListSection> createState() => _OrderListSectionState();
}

class _OrderListSectionState extends ConsumerState<OrderListSection> {
  late ScrollController _scrollController;
  int pageNo = 1;
  int perPage = 10;
  bool isLoadingMore = false;
  double scrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    scrollPosition = _scrollController.position.pixels;
    // Check if the user has scrolled to the bottom of the list
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !isLoadingMore) {
      // update scroll position
      // setState(() {});

      // Load more orders when scrolling reaches the end and pagination is needed
      final orderState = ref.read(orderListProvider);
      if (orderState is AsyncData && orderState.value != null) {
        if (orderState.value!.total > pageNo * perPage) {
          setState(() {
            isLoadingMore = true;
            pageNo++;
          });

          // Load more data for pagination
          ref
              .read(orderListProvider.notifier)
              .getOrders(page: pageNo, perPage: perPage)
              .then((_) {
            setState(() {
              isLoadingMore = false;
            });
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(orderListProvider).when(
          data: (orderData) {
            Future.delayed(Duration.zero, () {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(scrollPosition);
              }
            });
            return orderData.orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("No Orders Found"),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.refresh(orderListProvider);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Refresh"),
                        ),
                      ],
                    ),
                  )
                : Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        // Reset page number and refresh the list on pull-to-refresh
                        pageNo = 1;
                        await ref
                            .read(orderListProvider.notifier)
                            .refreshOrders(page: pageNo, perPage: perPage);
                      },
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(10),
                          controller: _scrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          itemCount:
                              orderData.orders.length + (isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == orderData.orders.length &&
                                isLoadingMore) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return OrderCard(
                              index: index,
                              orderData: orderData.orders[index],
                            );
                          },
                        ),
                      ),
                    ),
                  );
          },
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Error: $error"),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.refresh(orderListProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }
}

class DotAnimation extends StatefulWidget {
  @override
  _DOTAnimationState createState() => _DOTAnimationState();
}

class _DOTAnimationState extends State<DotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> size;
  late Animation<double> opacity;

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(duration: const Duration(seconds: 1), vsync: this)
          ..repeat();
    size = Tween(begin: 10.0, end: 25.0).animate(controller);
    opacity = Tween(begin: 1.0, end: 0.01).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 26.r,
          width: 26.r,
        ),
        AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return Container(
                height: size.value,
                width: size.value,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(0xFF1EDD31).withOpacity(opacity.value),
                  shape: BoxShape.circle,
                ),
              );
            }),
        Container(
          height: 11.r,
          width: 11.r,
          decoration: BoxDecoration(
            color: Color(0xFF1EDD31),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColor.greyColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);

    var dashArray = [5.0, 5.0];
    for (int i = 0; i < path.computeMetrics().length; i++) {
      var metric = path.computeMetrics().elementAt(i);
      var start = 0.0;
      while (start < metric.length) {
        final end = start + dashArray[0];
        var linePath = metric.extractPath(start, end);
        canvas.drawPath(linePath, paint);
        start += dashArray[0] + dashArray[1];
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
