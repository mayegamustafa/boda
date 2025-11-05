import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razinshop_rider/config/app_color.dart';
import 'package:razinshop_rider/utils/extensions.dart';
import 'package:razinshop_rider/views/home/components/new_order_dialog.dart';
import 'package:razinshop_rider/views/home/layouts/drawer.dart';
import 'package:razinshop_rider/views/home/layouts/header_section.dart';
import 'package:razinshop_rider/views/home/layouts/order_list_section.dart';
import 'package:razinshop_rider/views/home/layouts/summery_section.dart';
import 'package:razinshop_rider/services/order_notification_service.dart';

class HomeLayout extends ConsumerStatefulWidget {
  const HomeLayout({super.key});

  @override
  ConsumerState<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends ConsumerState<HomeLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      // Start monitoring for new orders
      ref.read(orderNotificationServiceProvider).startOrderMonitoring();
      // showNewOrderDialog();
    });
  }
  
  @override
  void dispose() {
    // Stop monitoring when leaving home screen
    ref.read(orderNotificationServiceProvider).stopOrderMonitoring();
    super.dispose();
  }

  void showNewOrderDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return NewOrderDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // backgroundColor: AppColor.whiteColor,
      backgroundColor: context.isDark ? Colors.black : AppColor.whiteColor,
      drawer: MyDrawer(),
      body: Column(
        children: [
          HeaderSection(scaffoldKey: _scaffoldKey),
          SummerySection(),
          OrderListSection(),
        ],
      ),
    );
  }
}
