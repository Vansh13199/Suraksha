enum SosTriggerType {
  APP_TRIGGERED,
  ESP_TRIGGERED,
}

enum SosSender {
  PHONE_SIM,
  ESP_ESIM,
  INVALID,
}

enum SosLocationSource {
  PHONE_GPS,
  ESP_GPS,
  NONE,
  INVALID,
}

class SosRouteDecision {
  final SosSender sender;
  final SosLocationSource locationSource;
  final String? warningMessage;

  SosRouteDecision({
    required this.sender,
    required this.locationSource,
    this.warningMessage,
  });
}

class SosRoutingService {
  SosRouteDecision determineSosRoute({
    required SosTriggerType triggerType,
    required bool espConnected, // ESP SOS Connected
    required bool phoneInternet, // Phone Internet
    required bool espGps, // ESP GPS Connected (Available)
  }) {
    // Logic Rules:
    // 1. If ESP32 SOS is NOT connected:
    //    → Use phone internet + phone GPS.
    if (!espConnected) {
      return SosRouteDecision(
        sender: SosSender.PHONE_SIM,
        locationSource: SosLocationSource.PHONE_GPS,
        warningMessage: "ESP disconnected. Using Phone Fallback.",
      );
    }

    // (Implicit: ESP Connected is TRUE now)

    // 2. If ESP32 SOS is Connected AND Phone Internet is NOT Connected AND ESP32 GPS is Connected:
    //    → Use ESP32 WiFi/internet and ESP32 GPS coordinates.
    if (!phoneInternet && espGps) {
      return SosRouteDecision(
        sender: SosSender.ESP_ESIM, // Using ESP WiFi 
        locationSource: SosLocationSource.ESP_GPS,
      );
    }

    // 3. If ESP32 SOS is Connected AND Phone Internet is Connected AND ESP32 GPS is Connected:
    //    → Use phone internet to send SOS message.
    //    → Use ESP32 GPS for coordinates.
    if (phoneInternet && espGps) {
      return SosRouteDecision(
        sender: SosSender.PHONE_SIM,
        locationSource: SosLocationSource.ESP_GPS,
      );
    }

    // 4. If ESP32 SOS is Connected AND Phone Internet is Connected AND ESP32 GPS is NOT Connected:
    //    → Use phone internet to send SOS message.
    //    → Use phone GPS for coordinates.
    if (phoneInternet && !espGps) {
      return SosRouteDecision(
         sender: SosSender.PHONE_SIM,
         locationSource: SosLocationSource.PHONE_GPS,
      );
    }

    // 5. If ESP32 SOS is Connected AND Phone Internet is NOT Connected AND ESP32 GPS is NOT Connected:
    //    → (Not explicitly defined in prompt, but logically matches Rule 1 or fails. Falling back to invalid)
    return SosRouteDecision(
      sender: SosSender.INVALID,
      locationSource: SosLocationSource.INVALID,
      warningMessage: "No Internet (Phone/ESP) and No GPS. SOS Cancelled.",
    );
  }

  // Helper/Legacy stubs if needed, but primary logic is above.
  SosRouteDecision _handleAppTriggered(bool a, bool b, bool c) => determineSosRoute(triggerType: SosTriggerType.APP_TRIGGERED, espConnected: a, phoneInternet: b, espGps: c);
  SosRouteDecision _handleEspTriggered(bool a, bool b, bool c) => determineSosRoute(triggerType: SosTriggerType.ESP_TRIGGERED, espConnected: a, phoneInternet: b, espGps: c);
}
