import 'package:flutter/material.dart';
import '../services/emergency_service.dart';
import '../models/contact_model.dart';
import '../services/esp32_sos_service.dart'; // UPDATED
import '../services/connectivity_service.dart';
import '../services/sos_routing_service.dart';
import '../services/gps_availability_service.dart';
import '../services/auth_service.dart';
import 'package:geolocator/geolocator.dart'; // NEW
import '../models/emergency_contact_model.dart';

class SosProvider extends ChangeNotifier {
  final EmergencyService _emergencyService = EmergencyService();
  final Esp32SosService _espService = Esp32SosService(); // UPDATED
  final ConnectivityService _connectivityService = ConnectivityService();
  final SosRoutingService _routingService = SosRoutingService();
  final GpsAvailabilityService _gpsService = GpsAvailabilityService();
  final AuthService _authService = AuthService();

  List<EmergencyContact> _emergencyContacts = [];

  bool get isSosActive => _emergencyService.isSosActive;
  String? get currentSessionId => _emergencyService.currentSosSessionId;
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;

  SosProvider() {
    _espService.init(); // Initialize SOS Service
    _listenToEspTrigger();
    refreshContacts();
  }

  Future<void> refreshContacts() async {
    _emergencyContacts = await _authService.getEmergencyContacts();
    notifyListeners();
  }

  void _listenToEspTrigger() {
    _espService.sosTriggerStream.listen((triggered) {
      if (triggered) {
        handleEspTriggeredSos();
      } else {
        deactivateSos();
      }
    });
  }

  Future<void> handleAppTriggeredSos({bool isLowBattery = false}) async {
    print("HANDLING APP TRIGGERED SOS...");
    
    // NEW: Send GPS to SOS ESP if connected
    if (_espService.isConnected) {
      try {
        // We assume permissions are handled, but good to be safe or use a service
        // For now, dragging in Geolocator directly as requested
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        String sosMsg = "SOS:LAT:${position.latitude},LON:${position.longitude}";
        print("Sending to ESP: $sosMsg");
        await _espService.sendData(sosMsg);
      } catch (e) {
        print("Failed to send GPS to ESP: $e");
      }
    }

    await _executeSosLogic(SosTriggerType.APP_TRIGGERED, isLowBattery: isLowBattery);
  }

  Future<void> handleEspTriggeredSos() async {
     print("HANDLING ESP TRIGGERED SOS...");
    await _executeSosLogic(SosTriggerType.ESP_TRIGGERED);
  }

  Future<void> _executeSosLogic(SosTriggerType triggerType, {bool isLowBattery = false}) async {
    // 1. Gather State
    bool espConnected = _espService.isConnected;
    bool hasInternet = await _connectivityService.hasInternetConnection();
    
    // Check ESP GPS availability (from relayed data)
    bool espGps = _espService.isEspGpsAvailable; 
    
    print("State: Trigger=$triggerType, ESP=$espConnected, Net=$hasInternet, EspGps=$espGps");

    // 2. Determine Route
    final decision = _routingService.determineSosRoute(
      triggerType: triggerType,
      espConnected: espConnected,
      phoneInternet: hasInternet,
      espGps: espGps,
    );

    print("Decision: Sender=${decision.sender}, Loc=${decision.locationSource}, Warning=${decision.warningMessage}");

    // 3. Act
    if (decision.sender == SosSender.INVALID) {
      _showWarning(decision.warningMessage ?? "Unknown Error");
      return;
    }

    // 4. ALWAYS fetch fresh contacts before triggering to prevent sending to deleted users
    print("[SosProvider] Refreshing contacts list before SOS dispatch...");
    await refreshContacts();
    
    if (_emergencyContacts.isEmpty) {
      print("[SosProvider] WARNING: No emergency contacts found. SOS will proceed but notifications may fail.");
    }
    
    // Map contacts
    List<ContactModel> legacyContacts = _emergencyContacts.map((e) => ContactModel(
      id: e.id, 
      name: e.name, 
      phoneNumber: e.phoneNumber, 
      priority: 1
    )).toList();
    
    // 5. Execute based on Sender
    if (decision.sender == SosSender.PHONE_SIM) {
       // Using Phone Internet
       double? latOverride;
       double? lonOverride;
       
       if (decision.locationSource == SosLocationSource.ESP_GPS) {
          // Use ESP GPS Data
          latOverride = _espService.lastLat;
          lonOverride = _espService.lastLon;
          print("Using ESP GPS for SOS: $latOverride, $lonOverride");
       } else {
          print("Using Phone GPS for SOS");
       }
       
       await _emergencyService.activateSos(legacyContacts, latOverride: latOverride, lonOverride: lonOverride, isLowBattery: isLowBattery);
       
    } else if (decision.sender == SosSender.ESP_ESIM) {
       // Using ESP WiFi
       print("Initiating SOS via ESP32 WiFi...");
       await _espService.sendData("EXECUTE_SOS_WIFI");
       _showWarning("SOS sent to ESP for WiFi transmission.");
    }
    
    notifyListeners();
  }

  void _showWarning(String message) {
    debugPrint("WARNING UI: $message");
    // In a real app, use a GlobalKey<ScaffoldMessengerState> or similar to show SnackBar
    // For this context, we just print/log as requested "Show user-friendly warning" (via console/UI placeholder)
  }

  Future<void> deactivateSos() async {
    try {
      await _emergencyService.deactivateSos();
      notifyListeners();
    } catch (e) {
      debugPrint('SOS deactivation failed: $e');
    }
  }

  void addContact(EmergencyContact contact) {
    _emergencyContacts.add(contact);
    notifyListeners();
  }
}
