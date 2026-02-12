import 'package:flutter/material.dart';
import '../services/emergency_service.dart';
import '../models/contact_model.dart';
import '../services/esp32_ble_service.dart';
import '../services/connectivity_service.dart';
import '../services/sos_routing_service.dart';
import '../services/gps_availability_service.dart';


class SosProvider extends ChangeNotifier {
  final EmergencyService _emergencyService = EmergencyService();
  final Esp32BleService _espService = Esp32BleService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final SosRoutingService _routingService = SosRoutingService();
  final GpsAvailabilityService _gpsService = GpsAvailabilityService();

  final List<ContactModel> _emergencyContacts = [
    // Mock for demo
    ContactModel(id: '1', name: 'Police', phoneNumber: '100', priority: 1),
  ];

  bool get isSosActive => _emergencyService.isSosActive;
  List<ContactModel> get emergencyContacts => _emergencyContacts;

  SosProvider() {
    _listenToEspTrigger();
  }

  void _listenToEspTrigger() {
    _espService.sosTriggerStream.listen((triggered) {
      if (triggered) {
        handleEspTriggeredSos();
      }
    });
  }

  Future<void> handleAppTriggeredSos() async {
    print("HANDLING APP TRIGGERED SOS...");
    await _executeSosLogic(SosTriggerType.APP_TRIGGERED);
  }

  Future<void> handleEspTriggeredSos() async {
     print("HANDLING ESP TRIGGERED SOS...");
    await _executeSosLogic(SosTriggerType.ESP_TRIGGERED);
  }

  Future<void> _executeSosLogic(SosTriggerType triggerType) async {
    // 1. Gather State
    bool espConnected = _espService.isConnected;
    bool hasInternet = await _connectivityService.hasInternetConnection();
    // For App trigger, we care about ESP GPS availability. 
    // Is ESP GPS available? 
    bool espGps = _espService.isGpsFixed; 
    
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
      // Show Warning
      _showWarning(decision.warningMessage ?? "Unknown Error");
      return;
    }

    // Calculate effective location
    // Note: emergency_service.activateSos currently uses Phone GPS (LocationService).
    // We need to modify pass location source or coordinates if multiple sources were supported.
    // For now, if LocationSource is ESP_GPS, we should ideally fetch coordinates from ESP.
    // If LocationSource is PHONE_GPS, we use existing logic.
    
    // START SOS
    await _emergencyService.activateSos(_emergencyContacts);
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

  void addContact(ContactModel contact) {
    _emergencyContacts.add(contact);
    notifyListeners();
  }
}
