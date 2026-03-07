import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'esp32_sos_service.dart';
import '../providers/sos_provider.dart';

Future<void> initializeBackgroundService() async {
  if (Platform.isAndroid || Platform.isIOS) {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'suraksha_foreground', // id
    'Suraksha Plus', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'suraksha_foreground',
      initialNotificationTitle: 'Suraksha Plus',
      initialNotificationContent: 'Running background service',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [
        AndroidForegroundType.location,
        AndroidForegroundType.dataSync,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Suraksha Plus",
      content: "Background service active",
    );

    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // ========== INIT BLE IN BACKGROUND ISOLATE ==========
  // By initializing the Bluetooth connection here in the background isolate,
  // it will survive when the UI engine detaches (app swiped away).
  final espService = Esp32SosService();
  await espService.init();

  // Create SosProvider to handle emergency routing based on ESP triggers
  // (We instantiate it here so it registers listeners on Esp32SosService)
  final sosProvider = SosProvider();

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    bool isConnected = espService.isConnected;
    
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Suraksha Plus",
          content: isConnected 
              ? "SOS Device Connected" 
              : "Scanning for SOS Device...",
        );
      }
    }
    print('[BACKGROUND] BLE Connected: $isConnected | Current Time: ${DateTime.now()}');
  });
}
