import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'api_service.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!kIsWeb) {
    await Firebase.initializeApp();
    print('Handling background message: ${message.messageId}');
    
    // Initialize local notifications for background display
    final FlutterLocalNotificationsPlugin localNotifications = 
        FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await localNotifications.initialize(initSettings);
    
    // Create notification channel for Android (if not already created)
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications',
        importance: Importance.high,
      );
      
      await localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
    
    // Show notification if notification payload exists
    if (message.notification != null) {
      // Include title and body in payload for notification tap handling
      final payloadData = {
        ...message.data,
        'title': message.notification!.title ?? '',
        'body': message.notification!.body ?? '',
      };
      
      await localNotifications.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(payloadData),
      );
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;
  String? _fcmToken;
  Function(Map<String, dynamic>)? _onNotificationTap;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Skip Firebase initialization on web for now
    if (kIsWeb) {
      print('⚠️ Firebase Messaging not fully supported on web. Skipping initialization.');
      _initialized = true;
      return;
    }

    try {
      // Initialize FirebaseMessaging only on non-web platforms
      // Note: kIsWeb check already done above, this is safe
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request permissions
      NotificationSettings settings =
          await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('⚠️ User granted provisional notification permission');
      } else {
        print('❌ User declined notification permission');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _firebaseMessaging!.getToken();
      if (_fcmToken != null) {
        print('✅ FCM Token: $_fcmToken');
        await _registerTokenWithBackend(_fcmToken!);
      }

      // Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed: $newToken');
        _fcmToken = newToken;
        _registerTokenWithBackend(newToken);
      });

      // Setup foreground message handler
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Setup background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle notification tap when app is opened from terminated state
      _firebaseMessaging!.getInitialMessage().then((message) {
        if (message != null) {
          final data = {
            ...message.data,
            'title': message.notification?.title ?? '',
            'body': message.notification?.body ?? '',
          };
          _handleNotificationTap(data);
        }
      });

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final data = {
          ...message.data,
          'title': message.notification?.title ?? '',
          'body': message.notification?.body ?? '',
        };
        _handleNotificationTap(data);
      });

      _initialized = true;
      print('✅ NotificationService initialized');
    } catch (e) {
      print('❌ Error initializing NotificationService: $e');
      // Mark as initialized even on error to prevent retry loops
      _initialized = true;
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    // Skip on web
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            _handleNotificationTap(data);
          } catch (e) {
            print('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create notification channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message received: ${message.messageId}');

    // Show local notification
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      // Include title and body in payload for notification tap handling
      final payloadData = {
        ...message.data,
        'title': notification.title ?? '',
        'body': notification.body ?? '',
      };
      
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(payloadData),
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    print('🔔 Notification tapped: $data');
    if (_onNotificationTap != null) {
      _onNotificationTap!(data);
    }
  }

  /// Set callback for notification tap
  void setOnNotificationTap(Function(Map<String, dynamic>) callback) {
    _onNotificationTap = callback;
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final authToken = await ApiService.getToken();
      if (authToken == null) {
        print('⚠️ Cannot register FCM token: Not authenticated');
        return;
      }

      final deviceType = kIsWeb 
          ? 'web' 
          : (Platform.isAndroid ? 'android' : 'ios');
      final deviceId = await _getDeviceId();

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/notifications/register-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'fcm_token': token,
          'device_type': deviceType,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM token registered with backend');
      } else {
        print('❌ Failed to register FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error registering FCM token: $e');
    }
  }

  /// Get device ID (stored in SharedPreferences)
  Future<String?> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      // Generate a simple device ID (you can use a package like device_info_plus for better IDs)
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if service is initialized
  bool get isInitialized => _initialized;
}
