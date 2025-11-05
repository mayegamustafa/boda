import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:razinshop_rider/config/app_color.dart';
import 'package:razinshop_rider/config/app_constants.dart';
import 'package:razinshop_rider/config/theme.dart';
import 'package:razinshop_rider/routers.dart';
import 'package:razinshop_rider/services/firebase_messaging_service.dart';
import 'package:razinshop_rider/services/telemetry_service.dart';
import 'package:razinshop_rider/utils/global_function.dart';

import 'generated/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.authBox);
  await Hive.openBox(AppConstants.appSettingsBox);
  
  // Initialize telemetry service
  await TelemetryService().initialize();
  
  // Set background message handler for Firebase
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Log app startup
  await TelemetryService().logEvent(
    event: 'app_started',
    level: TelemetryLevel.info,
    data: {'startup_time': DateTime.now().toIso8601String()},
  );
  
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  Locale resolveLocale(String? langCode) {
    if (langCode != null) {
      return Locale(langCode);
    } else {
      return const Locale('en');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, child) {
            final languageNotifier = ref.watch(languageNotifierProvider);

            // Initialize Firebase Messaging Service
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FirebaseMessagingService.instance.initializeFirebaseMessaging(ref);
            });

            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'RazinShop Rider',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ref.watch(themeProvider),
              locale: languageNotifier.getCurrentLocal,
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: S.delegate.supportedLocales,
              routerConfig: router,
            );
          },
        );
      },
    );
  }

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
