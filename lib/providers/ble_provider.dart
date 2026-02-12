import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/esp32_ble_service.dart';

class BleProvider extends ChangeNotifier {
  final Esp32BleService _bleService = Esp32BleService();
  bool _isConnected = false;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  bool get isConnected => _isConnected;
  List<ScanResult> get scanResults => _scanResults;
  bool get isScanning => _isScanning;

  BleProvider() {
    _init();
  }

  void _init() {
    _bleService.init();
    _bleService.connectionStateStream.listen((isConnected) {
      _isConnected = isConnected;
      notifyListeners();
    });
  }



  Future<void> startScan() async {
    // Request permissions before scanning
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    bool isGranted = (statuses[Permission.locationWhenInUse]?.isGranted ?? false) &&
                     (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
                     (statuses[Permission.bluetoothConnect]?.isGranted ?? false);

    if (!isGranted) {
      print("Permissions denied for scanning");
      return; 
    }

    _isScanning = true;
    _scanResults = [];
    notifyListeners();

    await _bleService.startScan(onScanResults: (results) {
      _scanResults = results;
      notifyListeners();
    });
    
    // Auto stop loading indicator after scan timeout (15s)
    Future.delayed(const Duration(seconds: 15), () {
      if (_isScanning) {
        _isScanning = false;
        notifyListeners();
      }
    });
  }

  Future<void> stopScan() async {
    await _bleService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      await _bleService.connectToDevice(device);
    } catch (e) {
      print("Error connecting in provider: $e");
    }
  }

  Future<void> disconnect() async {
    await _bleService.disconnect();
  }
}
