import 'dart:async';
import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;

  Stream<LocationData> get locationStream => _location.onLocationChanged;

  Future<bool> requestPermissions() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }

    return true;
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      return await _location.getLocation().timeout(const Duration(seconds: 4));
    } catch (e) {
      print("Location Error: $e");
      return null;
    }
  }

  Future<void> startLiveTracking() async {
    try {
      // ❌ BACKGROUND MODE DISABLED FOR DEMO STABILITY
      // await _location.enableBackgroundMode(enable: true); 
      
      await _location.changeSettings(
        accuracy: LocationAccuracy.balanced,
        interval: 5000,
        distanceFilter: 0, // Send updates even when stationary
      );
    } catch (e) {
      print("Start Tracking Error: $e");
    }
  }

  Future<void> stopLiveTracking() async {
    try {
      // await _location.enableBackgroundMode(enable: false);
      await _location.changeSettings(
        accuracy: LocationAccuracy.balanced,
        interval: 60000,
      );
    } catch (e) {
       print("Stop Tracking Error: $e");
    }
  }
}
