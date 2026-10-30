import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:suraksha_plus/services/auth_service.dart';
import '../main.dart'; // To access navigatorKey and flutterLocalNotificationsPlugin
import '../screens/emergency_chat_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  safePrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();

  factory PushNotificationService() {
    return _instance;
  }

  PushNotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  String? _currentToken;

  Future<void> initialize() async {
    safePrint('[PushNotification] Requesting permissions...');
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
    safePrint('[PushNotification] Permission status: ${settings.authorizationStatus}');

    // Explicitly create the high-priority notification channel on Android
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    const AndroidNotificationChannel sosChannel = AndroidNotificationChannel(
      'sos_push_alerts',
      'SOS Push Alerts',
      description: 'Push notifications for incoming SOS alerts from contacts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await androidImplementation?.createNotificationChannel(sosChannel);

    // 2. Set Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Setup Foreground Listeners
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      safePrint('[PushNotification] 🚨 FOREGROUND MESSAGE RECEIVED!');
      safePrint('[PushNotification] Data Map: ${message.data}');
      safePrint('[PushNotification] Notification Title: ${message.notification?.title}');
      _showInAppAlert(message);
    });

    // 4. Setup interaction
    // Handle tap from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
       _handleNotificationTap(message);
    });
    
    // Handle tap from terminated state (cold start)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final sessionId = _extractId(initialMessage);
      if (sessionId != null && sessionId.isNotEmpty) {
        pendingDeepLinkSessionId = sessionId;
        safePrint('[PushNotification] Cold Start FCM queued. ID: $pendingDeepLinkSessionId');
        navigateToEmergencyChat(sessionId);
      }
    }

    // 5. Get and track the token
    _currentToken = await _fcm.getToken();
    safePrint('FCM Token: $_currentToken');
    
    // Immediate Sync to Backend
    if (_currentToken != null) {
      AuthService().syncFcmToken();
    }
    
    // Listen to token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _updateTokenInBackend(newToken);
    });
  }

  String? _extractId(RemoteMessage message) {
    final data = message.data;
    // 1. Try common data keys
    String? id = data['sessionId'] ?? data['id'] ?? data['session_id'];
    if (id != null && id.isNotEmpty) return id;

    // 2. Try scraping from Title or Body (Fail-safe backup)
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final fullText = '$title $body';
    
    // Check both formats: [ID: ...] and (ID: ...)
    for (final prefix in ['[ID: ', '(ID: ']) {
      if (fullText.contains(prefix)) {
        final startIndex = fullText.indexOf(prefix) + prefix.length;
        final closer = prefix.contains('[') ? ']' : ')';
        final endIndex = fullText.indexOf(closer, startIndex);
        if (endIndex != -1) {
          return fullText.substring(startIndex, endIndex).trim();
        }
      }
    }
    return null;
  }

  Future<void> _showInAppAlert(RemoteMessage message) async {
     final sessionId = _extractId(message) ?? '';
     safePrint("[PushNotification] Showing in-app alert (ID: $sessionId)");
     
     // Show a high-priority heads-up local notification
     const AndroidNotificationDetails androidSpec = AndroidNotificationDetails(
       'sos_push_alerts', 'SOS Push Alerts',
       channelDescription: 'Push notifications for incoming SOS alerts from contacts',
       importance: Importance.max,
       priority: Priority.high,
       fullScreenIntent: true,
       color: Color(0xFFE53935),
       playSound: true,
       enableVibration: true,
       category: AndroidNotificationCategory.alarm,
       visibility: NotificationVisibility.public,
     );
     const NotificationDetails platformSpec = NotificationDetails(
       android: androidSpec,
       iOS: DarwinNotificationDetails(
         presentAlert: true,
         presentSound: true,
         presentBadge: true,
       ),
     );
     
     await flutterLocalNotificationsPlugin.show(
       id: 200,
       title: message.notification?.title ?? '🚨 Emergency Alert',
       body: message.notification?.body ?? 'A contact needs help! Tap to track.',
       notificationDetails: platformSpec,
       payload: 'sos_session:$sessionId',
     );
  }
  
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final sessionId = _extractId(message);
    safePrint('[PushNotification] TAP DATA MAP: ${message.data}');
    
    if (sessionId != null && sessionId.isNotEmpty) {
      safePrint('[PushNotification] SOS Alert tapped. Navigating to Chat (ID: $sessionId)...');
      navigateToEmergencyChat(sessionId);
    } else if (message.data['type'] == 'SOS_ALERT') {
      safePrint('[PushNotification] ERROR: Found SOS alert but no sessionId could be extracted!');
    }
  }

  /// Global reliable navigator that retries if NavigatorState is initializing
  static void navigateToEmergencyChat(String sessionId) {
    safePrint('[PushNotification] navigateToEmergencyChat requested for ID: $sessionId');
    void tryPush(int attempts) {
      final nav = navigatorKey.currentState;
      if (nav != null) {
        safePrint('[PushNotification] Live Navigator Push executing for ID: $sessionId');
        nav.push(
          MaterialPageRoute(
            settings: RouteSettings(name: '/emergency_chat', arguments: sessionId),
            builder: (_) => EmergencyChatScreen(sessionId: sessionId),
          ),
        );
      } else if (attempts < 15) {
        Future.delayed(const Duration(milliseconds: 200), () => tryPush(attempts + 1));
      } else {
        safePrint('[PushNotification] ERROR: Navigator null after 15 attempts!');
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => tryPush(0));
  }

  Future<String?> getToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        safePrint('[PushNotification] Firebase not yet initialized. Helping out...');
        await Firebase.initializeApp();
      }
      
      int retries = 0;
      while (_currentToken == null && retries < 5) {
        _currentToken = await _fcm.getToken();
        if (_currentToken == null) {
          safePrint('[PushNotification] Token not ready, retrying ($retries/5)...');
          await Future.delayed(const Duration(seconds: 1));
          retries++;
        }
      }
      
      if (_currentToken != null) {
        safePrint('[PushNotification] Token retrieved successfully!');
      } else {
        safePrint('[PushNotification] Token retrieval timed out after 5 retries.');
      }
      
      return _currentToken;
    } catch (e) {
      safePrint('[PushNotification] getToken failed: $e');
      return null;
    }
  }

  void _updateTokenInBackend(String token) {
     AuthService().syncFcmToken();
  }
}
