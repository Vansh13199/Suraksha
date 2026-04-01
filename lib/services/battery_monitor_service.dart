import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assistant_provider.dart';
import '../main.dart'; // for navigatorKey

class BatteryMonitorService {
  static final BatteryMonitorService _instance = BatteryMonitorService._internal();

  factory BatteryMonitorService() {
    return _instance;
  }

  BatteryMonitorService._internal();

  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _pollingTimer;

  int _lastReportedBattery = 100;
  DateTime? _lastTriggerTime;

  Future<void> initialize() async {
    // Get initial state
    _lastReportedBattery = await _battery.batteryLevel;

    // Listen to OS state changes (charging, discharging)
    _batterySubscription = _battery.onBatteryStateChanged.listen((BatteryState state) async {
       if (state == BatteryState.discharging) {
         _checkBattery();
       }
    });

    // Fallback polling every 5 minutes in case OS stops firing events
    _pollingTimer = Timer.periodic(const Duration(minutes: 5), (_) {
       _checkBattery();
    });
  }

  void stop() {
    _batterySubscription?.cancel();
    _pollingTimer?.cancel();
  }

  Future<void> _checkBattery() async {
    try {
      final int currentLevel = await _battery.batteryLevel;
      
      if (currentLevel <= 15) {
        // Debounce: Only trigger if we dropped *across* the threshold
        // OR it's been > 30 mins since the last trigger and we are STILL <= 15%
        bool crossedThreshold = _lastReportedBattery > 15;
        bool cooldownPassed = _lastTriggerTime == null || 
                              DateTime.now().difference(_lastTriggerTime!).inMinutes > 30;

        if (crossedThreshold || cooldownPassed) {
          _lastTriggerTime = DateTime.now();
          _dispatchLowBatteryAlert(currentLevel);
        }
      }
      _lastReportedBattery = currentLevel;
    } catch (e) {
      print("[BatteryMonitor] Error checking battery: \$e");
    }
  }

  void _dispatchLowBatteryAlert(int level) {
    print("[BatteryMonitor] TRIGGERING LOW BATTERY SOS: \$level%");
    final currentContext = navigatorKey.currentContext;
    if (currentContext != null) {
      currentContext.read<AssistantProvider>().triggerLowBatteryAlert(level);
    }
  }
}
