class AppConstants {
  static const String appName = 'Suraksha+';
  
  // Shared Preferences Keys
  static const String keyUserLoggedIn = 'is_logged_in';
  static const String keyPairedDeviceId = 'paired_device_id';
  static const String keyEmergencyContacts = 'emergency_contacts';
  
  // UUIDs for BLE Service (Example UUIDs, replace with actual ESP32 UUIDs)
  static const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String characteristicUuidTx = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String characteristicUuidRx = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

  // Messages
  static const String sosMessageTemplate = "Help! I am in danger. Track my live location here: ";
  static const String privacyDisclaimer = "We value your privacy. Your location is NEVER tracked unless SOS is active.";
}
