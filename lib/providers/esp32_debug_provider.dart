import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/esp32_ble_service.dart';

enum LogType { info, success, error }

class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogType type;

  LogEntry({required this.message, required this.type})
      : timestamp = DateTime.now();
}

class Esp32DebugProvider extends ChangeNotifier {
  final Esp32BleService _bleService = Esp32BleService();
  
  // GPS State
  Position? _currentPosition;
  String _gpsStatus = "Unknown";
  bool _isFetchingGps = false;

  // BLE State
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _isConnected = false;

  // Auto Send
  bool _isAutoSendEnabled = false;
  Timer? _autoSendTimer;

  // Logs
  final List<LogEntry> _logs = [];

  // Getters
  Position? get currentPosition => _currentPosition;
  String get gpsStatus => _gpsStatus;
  bool get isFetchingGps => _isFetchingGps;
  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  bool get isAutoSendEnabled => _isAutoSendEnabled;
  List<LogEntry> get logs => _logs;

  Esp32DebugProvider() {
    _initConnectionListener();
  }

  void _initConnectionListener() {
    _bleService.connectionStateStream.listen((connected) {
      _isConnected = connected;
      addLog("BLE Connection Status: ${connected ? 'Connected' : 'Disconnected'}", 
        connected ? LogType.success : LogType.info);
      if (!connected && _isAutoSendEnabled) {
        toggleAutoSend(false); // Stop sending if disconnected
      }
      notifyListeners();
    });
  }

  void addLog(String message, LogType type) {
    _logs.add(LogEntry(message: message, type: type));
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // --- GPS Logic ---

  Future<void> fetchLocation() async {
    _isFetchingGps = true;
    notifyListeners();
    addLog("Requesting GPS location...", LogType.info);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gpsStatus = "Disabled";
        addLog("Location services are disabled.", LogType.error);
        _isFetchingGps = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _gpsStatus = "Denied";
          addLog("Location permissions are denied.", LogType.error);
          _isFetchingGps = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _gpsStatus = "Denied Forever";
        addLog("Location permissions are permanently denied.", LogType.error);
        _isFetchingGps = false;
        notifyListeners();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _gpsStatus = "Active";
      addLog("GPS Location Fetched: Lat:${_currentPosition!.latitude}, Lon:${_currentPosition!.longitude}", LogType.success);

    } catch (e) {
      _gpsStatus = "Error";
      addLog("Error fetching location: $e", LogType.error);
    } finally {
      _isFetchingGps = false;
      notifyListeners();
    }
  }

  // --- BLE Logic ---

  Future<void> startScan() async {
    if (_isScanning) return;
    
    // Check permissions first
    if (await Permission.bluetoothScan.request().isDenied || 
        await Permission.bluetoothConnect.request().isDenied ||
        await Permission.locationWhenInUse.request().isDenied) {
      addLog("Bluetooth permissions denied.", LogType.error);
      return;
    }

    _isScanning = true;
    _scanResults.clear();
    notifyListeners();
    addLog("Started BLE Scan...", LogType.info);

    try {
      await _bleService.startScan(onScanResults: (results) {
        _scanResults = results;
        notifyListeners();
      });
      
      // Auto stop after 15s (handled by service usually but good to update UI)
      Future.delayed(const Duration(seconds: 15), () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      addLog("Scan Error: $e", LogType.error);
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await _bleService.stopScan();
    _isScanning = false;
    addLog("Stopped BLE Scan.", LogType.info);
    notifyListeners();
  }

  Future<void> connect(BluetoothDevice device) async {
    addLog("Connecting to ${device.platformName}...", LogType.info);
    try {
      await _bleService.connectToDevice(device);
      addLog("Connected to ${device.platformName}", LogType.success);
    } catch (e) {
      addLog("Connection Failed: $e", LogType.error);
    }
  }

  Future<void> disconnect() async {
    addLog("Disconnecting...", LogType.info);
    await _bleService.disconnect();
  }

  // --- Data Sending Logic ---

  Future<void> sendGpsData() async {
    if (!_isConnected) {
      addLog("Cannot send: No device connected.", LogType.error);
      return;
    }

    // Refresh location to ensure it's latest
    await fetchLocation();

    if (_currentPosition == null) {
      addLog("Cannot send: GPS location unavailable.", LogType.error);
      return;
    }

    // Format: LAT:xx.xxxx,LON:yy.yyyy
    String data = "LAT:${_currentPosition!.latitude},LON:${_currentPosition!.longitude}";
    
    try {
      await _bleService.sendData(data);
      addLog("Sent: $data", LogType.success);
    } catch (e) {
      addLog("Failed to send data: $e", LogType.error);
    }
  }

  void toggleAutoSend(bool value) {
    _isAutoSendEnabled = value;
    if (_isAutoSendEnabled) {
      addLog("Auto Send Enabled (10s interval)", LogType.info);
      sendGpsData(); // Send immediately once
      _autoSendTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (!_isConnected) {
          toggleAutoSend(false);
          return;
        }
        sendGpsData();
      });
    } else {
      addLog("Auto Send Disabled", LogType.info);
      _autoSendTimer?.cancel();
      _autoSendTimer = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _autoSendTimer?.cancel();
    super.dispose();
  }
}
