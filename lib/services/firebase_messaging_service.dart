import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razinshop_rider/controllers/order_controller/order_controller.dart';
import 'package:razinshop_rider/utils/global_function.dart';

/// Firebase Cloud Messaging service for handling push notifications
class FirebaseMessagingService {
  final Ref ref;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  FirebaseMessagingService(this.ref);

  /// Initialize Firebase messaging and local notifications
  Future<void> initialize() async {
    try {
      // Initialize Firebase if not already initialized
      await Firebase.initializeApp();
      
      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      print('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Initialize local notifications
        await _initializeLocalNotifications();
        
        // Get and store FCM token
        String? token = await _firebaseMessaging.getToken();
        print('FCM Token: $token');
        // TODO: Send this token to your backend server to store with rider profile
        
        // Setup message handlers
        _setupMessageHandlers();
        
        // Subscribe to riders topic (optional - for broadcast messages)
        await _firebaseMessaging.subscribeToTopic('riders');
        
        print('Firebase messaging initialized successfully');
      } else {
        print('Notification permission denied');
      }
    } catch (e) {
      print('Error initializing Firebase messaging: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'order_notifications',
      'Order Notifications',
      description: 'Notifications for new order assignments and updates',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Setup Firebase message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages (app in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Check if app was opened from a terminated state by a notification
    _checkForInitialMessage();
  }

  /// Handle messages when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.data}');
    
    // Show local notification
    await _showLocalNotification(message);
    
    // Handle different notification types
    await _handleNotificationData(message.data);
  }

  /// Handle notification tap when app was in background
  void _handleMessageOpenedApp(RemoteMessage message) async {
    print('Notification opened app: ${message.data}');
    await _handleNotificationData(message.data);
  }

  /// Check for initial message when app starts from terminated state
  void _checkForInitialMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from terminated state by notification: ${initialMessage.data}');
      await _handleNotificationData(initialMessage.data);
    }
  }

  /// Handle notification data and perform appropriate actions
  Future<void> _handleNotificationData(Map<String, dynamic> data) async {
    final String? type = data['type'];
    
    switch (type) {
      case 'new_order':
        // Refresh orders list to show new assignment
        ref.invalidate(orderListProvider);
        
        // Show success snackbar
        GlobalFunction.showCustomSnackbar(
          message: 'New order assigned!',
          isSuccess: true,
        );
        break;
        
      case 'order_update':
        // Refresh specific order details if order ID provided
        final String? orderId = data['order_id'];
        if (orderId != null) {
          final int? id = int.tryParse(orderId);
          if (id != null) {
            ref.invalidate(orderDetailsProvider(id));
          }
        }
        // Also refresh general orders list
        ref.invalidate(orderListProvider);
        break;
        
      case 'broadcast':
        // Handle general broadcast messages
        GlobalFunction.showCustomSnackbar(
          message: data['message'] ?? 'New notification received',
          isSuccess: true,
        );
        break;
        
      default:
        print('Unknown notification type: $type');
        break;
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'order_notifications',
      'Order Notifications',
      channelDescription: 'Notifications for new order assignments and updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Total Ride',
      message.notification?.body ?? 'You have a new notification',
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        _handleNotificationData(data);
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
  }

  /// Get current FCM token (call this when user logs in to send to backend)
  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to topic (useful for broadcast messages)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    // Cancel any subscriptions if needed
  }
}

/// Provider for Firebase messaging service
final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService(ref);
});

/// Top-level function for handling background messages
/// This MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  print('Handling background message: ${message.messageId}');
  print('Background message data: ${message.data}');
  
  // You can show a local notification here if needed
  // For now, just log the message
}