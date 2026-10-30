import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide AuthProvider;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' hide AuthProvider;
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'amplifyconfiguration.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/ble_provider.dart';
import 'providers/sos_provider.dart';
import 'providers/esp32_debug_provider.dart';
import 'providers/modes_provider.dart';
import 'providers/assistant_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/emergency_chat_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/register_email_screen.dart';
import 'screens/user_details_screen.dart';
import 'screens/ekyc_verification_screen.dart';
import 'screens/sos_active_screen.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'services/background_service.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/battery_monitor_service.dart';
import 'services/emergency_service.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();

// 🛰️ DEEP LINK QUEUE: Stores the Session ID if the app opens via a cold-start notification tap
String? pendingDeepLinkSessionId;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase First
  try {
    await Firebase.initializeApp();
    safePrint('[Firebase] Initialized successfully');
  } catch (e) {
    safePrint('[Firebase] Init failed: $e');
  }

  // 2. Configure Amplify
  await _configureAmplify();

  // Initialize local notifications for UI tap handling
  const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('ic_bg_service_small');
  const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings();
  const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid, iOS: initSettingsIOS);
  
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        selectNotificationStream.add(response.payload);
      }
    },
  );

  // 4. Initial Sync (Guarantees registration before UI launch)
  try {
    await AuthService().syncFcmToken();
  } catch (_) {}

  runApp(const SurakshaPlusApp());

  // Initialize services safely after app launch
  Future.microtask(() async {
    safePrint('[Main] Starting secondary services...');
    
    // 1. Initialize Push Notification Service
    try {
      safePrint('[Main] Initializing PushNotificationService...');
      await PushNotificationService().initialize();
      safePrint('[Main] PushNotificationService ready');
    } catch (e) {
      safePrint('[Main] PushNotificationService failed: $e');
    }

    // 2. Initialize Background Service
    try {
      safePrint('[Main] Initializing BackgroundService...');
      await initializeBackgroundService();
      safePrint('[Main] BackgroundService ready');
    } catch (e) {
      safePrint('[Main] BackgroundService failed: $e');
    }

    // 3. Initialize Battery Monitor
    try {
      safePrint('[Main] Initializing BatteryMonitor...');
      await BatteryMonitorService().initialize();
      safePrint('[Main] BatteryMonitor ready');
    } catch (e) {
      safePrint('[Main] BatteryMonitor failed: $e');
    }
  });
}

Future<void> _configureAmplify() async {
  try {
    final authPlugin = AmplifyAuthCognito();
    final apiPlugin = AmplifyAPI();
    final storagePlugin = AmplifyStorageS3();

    await Amplify.addPlugins([authPlugin, apiPlugin, storagePlugin]);
    await Amplify.configure(amplifyconfig);

    safePrint('[Amplify] Configured successfully');
  } on AmplifyAlreadyConfiguredException {
    safePrint('[Amplify] Already configured — skipping');
  } on Exception catch (e) {
    safePrint('[Amplify] Configuration failed: $e');
  }
}

class SurakshaPlusApp extends StatefulWidget {
  const SurakshaPlusApp({super.key});

  @override
  State<SurakshaPlusApp> createState() => _SurakshaPlusAppState();
}

class _SurakshaPlusAppState extends State<SurakshaPlusApp> {
  StreamSubscription? _sub;
  StreamSubscription? _ipcSub;

  @override
  void initState() {
    super.initState();
    _handleColdStart();
    _sub = selectNotificationStream.stream.listen((String? payload) {
      _routePayload(payload);
    });

    // Listen to IPC events from Background Service when SOS triggers while app is in background
    _ipcSub = FlutterBackgroundService().on('sos_status_changed').listen((event) {
      if (event != null) {
        final bool isActive = event['isActive'] ?? false;
        final String? sessionId = event['sessionId'];
        safePrint('[Main] IPC Received sos_status_changed: isActive=$isActive, sessionId=$sessionId');

        // Keep UI isolate's EmergencyService synchronized
        EmergencyService().setSosActiveState(isActive, sessionId: sessionId);

        if (isActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navState = navigatorKey.currentState;
            if (navState != null) {
              bool alreadyOnScreen = false;
              navState.popUntil((route) {
                if (route.settings.name == '/sos_active') {
                  alreadyOnScreen = true;
                }
                return true;
              });
              if (!alreadyOnScreen) {
                navState.push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/sos_active'),
                    builder: (_) => const SosActiveScreen(),
                  ),
                );
              }
            }
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigatorKey.currentState?.popUntil((route) => route.settings.name != '/sos_active');
          });
        }
      }
    });
  }

  void _handleColdStart() async {
    final details = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.startsWith('sos_session:')) {
        // Queue the ID instead of fighting the SplashScreen race condition
        pendingDeepLinkSessionId = payload.replaceFirst('sos_session:', '');
        safePrint('[Main] Cold Start Local Notification queued. ID: $pendingDeepLinkSessionId');
        PushNotificationService.navigateToEmergencyChat(pendingDeepLinkSessionId!);
      } else if (payload == 'sos_active') {
        pendingDeepLinkSessionId = 'SOS_ACTIVE_SCREEN';
        safePrint('[Main] Cold Start SOS Active Notification queued.');
      }
    }
  }

  Future<void> _routePayload(String? payload) async {
    safePrint('[Main] Routing with payload: $payload');
    if (payload == null) return;

    if (payload == 'sos_active') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navState = navigatorKey.currentState;
        if (navState != null) {
          bool alreadyOnScreen = false;
          navState.popUntil((route) {
            if (route.settings.name == '/sos_active') {
              alreadyOnScreen = true;
            }
            return true;
          });
          if (!alreadyOnScreen) {
            navState.push(
              MaterialPageRoute(
                settings: const RouteSettings(name: '/sos_active'),
                builder: (_) => const SosActiveScreen(),
              ),
            );
          }
        }
      });
    } else if (payload == 'emergency_chat') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const EmergencyChatScreen()),
      );
    } else if (payload.startsWith('sos_session:')) {
      final sessionId = payload.replaceFirst('sos_session:', '');
      PushNotificationService.navigateToEmergencyChat(sessionId);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ipcSub?.cancel();
    selectNotificationStream.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BleProvider(), lazy: false),
        ChangeNotifierProvider(create: (_) => SosProvider(), lazy: false),
        ChangeNotifierProvider(create: (_) => Esp32DebugProvider()),
        ChangeNotifierProvider(create: (_) => ModesProvider()),
        ChangeNotifierProvider(create: (_) => AssistantProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Suraksha+',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.waitForInit();

    if (!mounted) return;

    Widget nextScreen;
    if (authProvider.isSignedIn) {
      if (authProvider.currentUser != null) {
        if (authProvider.currentUser!.isEkycVerified) {
          if (authProvider.currentUser!.firstName != null &&
              authProvider.currentUser!.firstName!.isNotEmpty) {
            nextScreen = const HomeDashboardScreen();
          } else {
            nextScreen = const UserDetailsScreen();
          }
        } else {
          nextScreen = const EkycVerificationScreen();
        }
      } else {
        nextScreen = const EkycVerificationScreen();
      }
    } else {
      nextScreen = const RegisterEmailScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );


  }

  @override
  Widget build(BuildContext context) {
    // Return a solid blue background that matches the native splash to prevent any visual tearing
    return const Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: SizedBox.expand(),
    );
  }
}
