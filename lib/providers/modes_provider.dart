import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/esp32_sos_service.dart';

class ModesProvider extends ChangeNotifier {
  final Esp32SosService _espService = Esp32SosService();

  bool _isActivityMode = false;
  int _selectedTimerMinutes = 5; // Default 5 minutes
  int _remainingSeconds = 0;
  Timer? _activityTimer;

  bool get isActivityMode => _isActivityMode;
  int get selectedTimerMinutes => _selectedTimerMinutes;
  int get remainingSeconds => _remainingSeconds;

  ModesProvider() {
    _loadSettings();
    _listenToBleTaps();
    _listenToBleActivity();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isActivityMode = prefs.getBool('isActivityMode') ?? false;
    _selectedTimerMinutes = prefs.getInt('activityTimerMinutes') ?? 5;
    
    if (_isActivityMode) {
      _isActivityMode = false;
      prefs.setBool('isActivityMode', false);
    }
    notifyListeners();
  }

  void _listenToBleTaps() {
    _espService.tapEventStream.listen((tapCount) {
      if (tapCount == 4) {
        print("[ModesProvider] Received 4 taps. Starting Activity Mode.");
        _setActivityFromEsp(true);
      } else if (tapCount == 3) {
        print("[ModesProvider] Received 3 taps. Stopping Activity Mode.");
        _setActivityFromEsp(false);
      }
    });
  }

  /// Listen for ACTIVITY:ENABLED / ACTIVITY:DISABLED from ESP32 via BLE
  void _listenToBleActivity() {
    _espService.activityModeStream.listen((isEnabled) {
      print("[ModesProvider] ESP32 Activity signal received: $isEnabled");
      _setActivityFromEsp(isEnabled);
    });
  }

  void setTimerMinutes(int minutes) {
    _selectedTimerMinutes = minutes;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('activityTimerMinutes', minutes);
    });
    notifyListeners();
  }

  /// Called when the signal comes FROM the ESP32 (tap or BLE).
  /// Updates UI state but does NOT send a signal back to the ESP (prevents loop).
  Future<void> _setActivityFromEsp(bool isActive) async {
    if (_isActivityMode == isActive && !isActive) return;

    _isActivityMode = isActive;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isActivityMode', isActive);

    if (isActive) {
      _startTimer();
    } else {
      _stopTimer();
    }

    notifyListeners();
  }

  /// Called when the user presses the Activity button in the app.
  /// Updates UI state AND sends a signal to the ESP32 via BLE.
  Future<void> setActivityMode(bool isActive) async {
    if (_isActivityMode == isActive && !isActive) return;

    _isActivityMode = isActive;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isActivityMode', isActive);

    if (isActive) {
      // START ACTIVITY MODE
      _startTimer();
      // Send ACTIVITY:1,SECONDS:X to ESP32 (GPS ESP forwards via UDP to SOS ESP)
      int totalSeconds = _selectedTimerMinutes * 60;
      _espService.sendData("ACTIVITY:1,SECONDS:$totalSeconds");
    } else {
      // STOP ACTIVITY MODE (NORMAL MODE)
      _stopTimer();
      // Send ACTIVITY:0 to ESP32
      _espService.sendData("ACTIVITY:0");
    }

    notifyListeners();
  }

  void _startTimer() {
    _activityTimer?.cancel();
    _remainingSeconds = _selectedTimerMinutes * 60;
    
    _activityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        // Timer finished — revert to normal mode and tell ESP
        setActivityMode(false);
      }
    });
  }

  void _stopTimer() {
    _activityTimer?.cancel();
    _remainingSeconds = 0;
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    super.dispose();
  }
}
