import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class Esp32SosService {
  // Singleton pattern
  static final Esp32SosService _instance = Esp32SosService._internal();

  factory Esp32SosService() {
    return _instance;
  }

  Esp32SosService._internal();

  final AuthService _authService = AuthService();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic; // ESP32 TX -> App RX (Notify)
  BluetoothCharacteristic? _txCharacteristic; // App TX -> ESP32 RX (Write)
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

  // Tap Events Stream (From ESP32)
  final _tapEventController = StreamController<int>.broadcast();
  Stream<int> get tapEventStream => _tapEventController.stream;

  // Activity Mode Stream (From ESP32 via BLE)
  final _activityModeController = StreamController<bool>.broadcast();
  Stream<bool> get activityModeStream => _activityModeController.stream;

  // GPS Data (Relayed from GPS ESP)
  double? _lastLat;
  double? _lastLon;
  DateTime? _lastGpsTimestamp;
  
  double? get lastLat => _lastLat;
  double? get lastLon => _lastLon;

  bool get isEspGpsAvailable {
    if (_lastGpsTimestamp == null) return false;
    return DateTime.now().difference(_lastGpsTimestamp!) < const Duration(seconds: 20);
  }

  static const String keyPairedSosDeviceId = "paired_sos_device_id";

  Future<void> init() async {
    if (await FlutterBluePlus.isSupported == false) {
      print("[SOS Service] Bluetooth not supported");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String? savedDeviceId = prefs.getString(keyPairedSosDeviceId);
    
    if (savedDeviceId != null) {
       _tryAutoConnect(savedDeviceId);
    } else {
      startScan(); 
    }
  }

  Future<void> startScan({Function(List<ScanResult>)? onScanResults}) async {
    if (FlutterBluePlus.isScanningNow) {
     await FlutterBluePlus.stopScan();
    }
    
    print("[SOS Service] Scanning...");
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
    
    print("[SOS Service] Connecting to device: ${device.platformName} (${device.remoteId.str})");

    try {
      await device.connect(autoConnect: false);
      _connectedDevice = device;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyPairedSosDeviceId, device.remoteId.str);

      _connectionStateController.add(true);
  
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionStateController.add(false);
          print("[SOS Service] Device Disconnected.");
        }
      });
      
      // Discover services AFTER connecting
      await _discoverServices(device);

      // --- SYNC IDENTITY ON CONNECT ---
      await Future.delayed(const Duration(seconds: 1));
      final phone = await _authService.getUserPhone();
      if (phone != null) {
        print("[SOS Service] Syncing user identity: $phone");
        await sendData("SET_PHONE:$phone");
      }
      
    } catch (e) {
      print("[SOS Service] Connection Error: $e");
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    print("[SOS Service] === SERVICE DISCOVERY ===");
    print("[SOS Service] Found ${services.length} services");
    
    for (var service in services) {
       print("[SOS Service]   Service: ${service.uuid}");
       for (var characteristic in service.characteristics) {
         String uuid = characteristic.uuid.toString().toUpperCase();
         print("[SOS Service]     Char UUID: $uuid");
         
         // RX Characteristic (Notify) - Receive Data from ESP
         if (uuid == AppConstants.characteristicUuidRx) {
           _rxCharacteristic = characteristic;
           print("[SOS Service] >>> RX (Notify) characteristic FOUND! Setting up notifications...");
           await _rxCharacteristic!.setNotifyValue(true);
           print("[SOS Service] >>> Notifications ENABLED on RX");
           
           _rxCharacteristic!.onValueReceived.listen((value) {
               final String data = String.fromCharCodes(value);
               print("[SOS Service] <<< Rx from ESP: '$data'");
               
               // SOS trigger — must match exactly to avoid SOS:STOP re-triggering
               if (data.trim() == "SOS:START") {
                 print("[SOS Service] !!! SOS TRIGGERED from ESP32");
                 _sosTriggerController.add(true);
               } else if (data.trim() == "SOS:STOP") {
                 print("[SOS Service] !!! SOS STOP received from ESP32");
                 _sosTriggerController.add(false);
               }

               // Activity Mode signals
               if (data.contains("ACTIVITY:ENABLED")) {
                 print("[SOS Service] >>> Activity Mode ENABLED by ESP32");
                 _activityModeController.add(true);
               } else if (data.contains("ACTIVITY:DISABLED")) {
                 print("[SOS Service] >>> Activity Mode DISABLED by ESP32");
                 _activityModeController.add(false);
               }

               // Tap Events
               if (data.startsWith("TAP:")) {
                  try {
                    int tapCount = int.parse(data.split(":")[1].trim());
                    print("[SOS Service] Parsed Tap Count: $tapCount");
                    _tapEventController.add(tapCount);
                  } catch (e) {
                    print("[SOS Service] Error parsing TAP: $e");
                  }
               }
               
               // GPS data relay
               if (data.contains("LAT:") && data.contains("LON:")) {
                  try {
                    final latStr = data.split("LAT:")[1].split(",")[0];
                    final lonStr = data.split("LON:")[1];
                    _lastLat = double.tryParse(latStr);
                    _lastLon = double.tryParse(lonStr);
                    _lastGpsTimestamp = DateTime.now();
                  } catch (e) {
                    print("[SOS Service] Error parsing GPS: $e");
                  }
               }
             });
         }
         
         // TX Characteristic (Write) - Send Data to ESP
         if (uuid == AppConstants.characteristicUuidTx) {
           _txCharacteristic = characteristic;
           print("[SOS Service] >>> TX (Write) characteristic FOUND!");
         }
       }
    }
    
    // Summary
    print("[SOS Service] === DISCOVERY COMPLETE ===");
    print("[SOS Service] RX found: ${_rxCharacteristic != null}, TX found: ${_txCharacteristic != null}");
    if (_rxCharacteristic == null) {
      print("[SOS Service] WARNING: RX not found! Expected UUID: ${AppConstants.characteristicUuidRx}");
    }
    if (_txCharacteristic == null) {
      print("[SOS Service] WARNING: TX not found! Expected UUID: ${AppConstants.characteristicUuidTx}");
    }
  }
  
  Future<void> sendData(String data) async {
    if (_connectedDevice == null || _txCharacteristic == null) {
      print("[SOS Service] Cannot send, device or characteristic missing. Connected: ${_connectedDevice != null}, TX: ${_txCharacteristic != null}");
      return;
    }

    try {
      await _txCharacteristic!.write(utf8.encode(data), withoutResponse: false);
      print("[SOS Service] Sent: $data");
    } catch (e) {
      print("[SOS Service] Error sending data: $e");
    }
  }

  Future<void> _tryAutoConnect(String deviceId) async {
    await startScan();
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _connectionStateController.add(false);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyPairedSosDeviceId);
  }
}
