import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Esp32BleService {
  // Singleton pattern
  static final Esp32BleService _instance = Esp32BleService._internal();

  factory Esp32BleService() {
    return _instance;
  }

  Esp32BleService._internal();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  // Stream for UI
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _connectedDevice != null;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // SOS Stream
  final _sosTriggerController = StreamController<bool>.broadcast();
  Stream<bool> get sosTriggerStream => _sosTriggerController.stream;

  // GPS Status
  bool _isGpsFixed = false;
  bool get isGpsFixed => _isGpsFixed;


  Future<void> init() async {
    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported");
      return;
    }

    // Attempt auto-reconnect if device ID is saved
    final prefs = await SharedPreferences.getInstance();
    final String? savedDeviceId = prefs.getString(AppConstants.keyPairedDeviceId);
    
    if (savedDeviceId != null) {
       _tryAutoConnect(savedDeviceId);
    }
  }

  Future<void> startScan({Function(List<ScanResult>)? onScanResults}) async {
    // Stop any existing scan
    if (FlutterBluePlus.isScanningNow) {
     await FlutterBluePlus.stopScan();
    }
    
    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (onScanResults != null) {
        onScanResults(results);
      }
    });
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await stopScan();
    
    try {
      await device.connect(autoConnect: false);
      _connectedDevice = device;
      
      // Save Device ID for auto-reconnect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyPairedDeviceId, device.remoteId.str);

      _connectionStateController.add(true);
      
      // Discover services
      await _discoverServices(device);
      
      // Listen to connection state for disconnects
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionStateController.add(false);
          // Auto-reconnect logic is handled by autoConnect: true in connect(),
          // but if we need manual logic, we add it here.
          print("Device Disconnected. Attempting reconnect...");
          device.connect(autoConnect: false);
        }
      });
      
    } catch (e) {
      print("Connection Error: $e");
      rethrow;
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
       // Ideally filter by AppConstants.serviceUuid
       for (var characteristic in service.characteristics) {
         if (characteristic.uuid.toString().toUpperCase() == AppConstants.characteristicUuidRx) {
           _rxCharacteristic = characteristic;
           // Enable notifications
           await _rxCharacteristic!.setNotifyValue(true);
             _rxCharacteristic!.onValueReceived.listen((value) {
               // Handle incoming data
               final String data = String.fromCharCodes(value);
               print("Received from ESP32: $data");
               
               if (data.contains("SOS")) {
                 _sosTriggerController.add(true);
               }
               
               if (data.contains("GPS_FIXED")) {
                 _isGpsFixed = true;
               } else if (data.contains("GPS_LOST")) {
                 _isGpsFixed = false;
               }
             });
         }
         if (characteristic.uuid.toString().toUpperCase() == AppConstants.characteristicUuidTx) {
           _txCharacteristic = characteristic;
         }
       }
    }
  }
  
  Future<void> _tryAutoConnect(String deviceId) async {
    // In FlutterBluePlus, we can't get a device object just from ID without scanning 
    // or if it's already in the known system devices.
    // Logic: Start a scan, look for this ID, then connect.
    await startScan(onScanResults: (results) {
      for (var result in results) {
        if (result.device.remoteId.str == deviceId) {
          connectToDevice(result.device);
          break;
        }
      }
    });
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _connectionStateController.add(false);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyPairedDeviceId);
  }
}
