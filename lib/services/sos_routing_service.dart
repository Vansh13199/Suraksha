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
    required bool espConnected,
    required bool phoneInternet,
    required bool espGps,
  }) {
    if (triggerType == SosTriggerType.APP_TRIGGERED) {
      return _handleAppTriggered(espConnected, phoneInternet, espGps);
    } else {
      return _handleEspTriggered(espConnected, phoneInternet, espGps);
    }
  }

  SosRouteDecision _handleAppTriggered(
    bool espConnected,
    bool phoneInternet,
    bool espGps,
  ) {
    // A) APP-TRIGGERED SOS (Truth Table)
    // | ESP Connected | Phone Internet | ESP GPS | SOS Sender | Location |
    // |---|---|---|---|---|
    // | ❌ | ❌ | ❌ | **INVALID** | **INVALID** |
    // | ❌ | ✅ | ❌ | Phone SIM | Phone GPS |
    // | ❌ | ✅ | ✅ | Phone SIM | Phone GPS | -- Note: If ESP is not connected, we verify ESP GPS is naturally false/irrelevant effectively, but based on table row 3 (false, true, true) -> Phone SIM, Phone GPS. However, how can ESP GPS be true if ESP is not connected? The table assumes conceptual availability. If ESP is disconnected, we can't read its GPS. So practically this row collapses to row 2.
    // | ✅ | ❌ | ✅ | ESP eSIM | ESP GPS |
    // | ✅ | ✅ | ✅ | Phone SIM | ESP GPS |
    // | ✅ | ✅ | ❌ | Phone SIM | Phone GPS |

    if (!espConnected) {
      if (!phoneInternet) {
        // Row 1: False, False, * -> INVALID
        return SosRouteDecision(
          sender: SosSender.INVALID,
          locationSource: SosLocationSource.INVALID,
          warningMessage: "No connection available (Phone offline, ESP disconnected). Cannot send SOS.",
        );
      } else {
        // Row 2 & 3: False, True, * -> Phone SIM, Phone GPS
        return SosRouteDecision(
          sender: SosSender.PHONE_SIM,
          locationSource: SosLocationSource.PHONE_GPS,
        );
      }
    } else {
      // ESP Connected is TRUE
      if (!phoneInternet) {
        if (espGps) {
          // Row 4: True, False, True -> ESP eSIM, ESP GPS
          return SosRouteDecision(
            sender: SosSender.ESP_ESIM,
            locationSource: SosLocationSource.ESP_GPS,
          );
        } else {
          // Implicitly invalid or missing from strict table?
          // Table says: False, False, False -> Invalid.
          // Table row 4 covers True, False, True.
          // What about True, False, False?
          // Looking at the table provided in Step 2:
          // A) APP-TRIGGERED
          // First row: X, X, X -> INVALID.
          // My code handles !espConnected && !phoneInternet.
          // Now I am in espConnected=True, phoneInternet=False.
          // If espGps=True -> Row 4.
          // If espGps=False -> It's not explicitly in the valid rows?
          // Let's re-read:
          // Row 1: X X X -> Invalid
          // Row 2: X V X -> Phone
          // Row 3: X V V -> Phone
          // Row 4: V X V -> ESP
          // Row 5: V V V -> Phone / ESP GPS
          // Row 6: V V X -> Phone / Phone GPS
          
          // Case: True, False, False. (ESP conn, No Internet, No ESP GPS).
          // NOT in valid rows. Fallback to INVALID per "If ANY state falls outside... return INVALID"
           return SosRouteDecision(
            sender: SosSender.INVALID,
            locationSource: SosLocationSource.INVALID,
             warningMessage: "Phone offline and ESP GPS unavailable. Cannot send SOS reliably.",
          );
        }
      } else {
        // Phone Internet is TRUE
        if (espGps) {
          // Row 5: True, True, True -> Phone SIM, ESP GPS
          return SosRouteDecision(
            sender: SosSender.PHONE_SIM,
            locationSource: SosLocationSource.ESP_GPS,
          );
        } else {
          // Row 6: True, True, False -> Phone SIM, Phone GPS
          return SosRouteDecision(
            sender: SosSender.PHONE_SIM,
            locationSource: SosLocationSource.PHONE_GPS,
          );
        }
      }
    }
  }

  SosRouteDecision _handleEspTriggered(
    bool espConnected,
    bool phoneInternet,
    bool espGps,
  ) {
    // B) ESP-TRIGGERED SOS (Truth Table)
    // | ESP Connected | Phone Internet | ESP GPS | SOS Sender | Location |
    // |---|---|---|---|---|
    // | ❌ | ❌ | ✅ | ESP eSIM | ESP GPS | -- Note: ESP not connected to Phone, but ESP triggered it internally.
    // | ❌ | ✅ | ✅ | ESP eSIM | ESP GPS |
    // | ✅ | ❌ | ✅ | ESP eSIM | ESP GPS |
    // | ✅ | ✅ | ✅ | Phone SIM | ESP GPS |
    // | ✅ | ✅ | ❌ | Phone SIM | Phone GPS |
    // | ❌ | ✅ | ❌ | **INVALID** | **INVALID** |

    // Note on "ESP Connected": This refers to "ESP Connected to App via BLE".
    // If ESP triggers SOS, it means ESP is alive.
    // If ESP is NOT connected to App (BLE), we (the App) might not even know about this trigger immediately 
    // UNLESS this logic runs on the ESP? 
    // BUT the prompt says "Implement SOS routing logic ONLY... decision engine".
    // This engine likely runs on the Phone App. 
    // If ESP is NOT connected (BLE), the App can't receive the trigger to run this logic?
    // WARNING: If the trigger suggests "ESP_TRIGGERED", it implies the App received that signal.
    // Therefore, for the App to run "determineSosRoute(ESP_TRIGGERED...)", 
    // ESP MUST be connected?
    // OR, maybe the logic is shared or simulated? 
    // Let's adhere strictly to the table provided. 
    // Row 1 & 2 say "ESP Connected: X" yet "SOS Sender: ESP eSIM". 
    // This implies that if the App is not reachable, ESP handles it itself. 
    // Since I am writing Dart code for the Flutter App, I can only execute this if I know about the trigger.
    // If ESP is disconnected, I technically can't run this function in response to a BLE message.
    // However, I will implement the logic exactly as requested for the engine.

    if (!espConnected) {
       if (espGps) {
         // Row 1: False, False, True -> ESP eSIM
         // Row 2: False, True, True -> ESP eSIM
         // Combined: !Connected && Gps -> ESP eSIM
         return SosRouteDecision(
           sender: SosSender.ESP_ESIM,
           locationSource: SosLocationSource.ESP_GPS,
         );
       } else {
         // Row 6 (implied context): False, True, False -> INVALID?? 
         // The table says: X, V, X -> INVALID.
         // Also X, X, X is likely INVALID too.
         return SosRouteDecision(
           sender: SosSender.INVALID,
           locationSource: SosLocationSource.INVALID,
           warningMessage: "ESP triggered but disconnected and NO GPS. Cannot process.",
         );
       }
    } else {
      // ESP Connected = TRUE
      if (!phoneInternet) {
        if (espGps) {
          // Row 3: True, False, True -> ESP eSIM, ESP GPS
          return SosRouteDecision(
            sender: SosSender.ESP_ESIM,
            locationSource: SosLocationSource.ESP_GPS,
          );
        } else {
           // True, False, False -> Not in valid rows -> INVALID
           return SosRouteDecision(
            sender: SosSender.INVALID,
            locationSource: SosLocationSource.INVALID,
            warningMessage: "ESP Triggered: Phone offline and ESP GPS unavailable.",
          );
        }
      } else {
        // Phone Internet = TRUE
        if (espGps) {
          // Row 4: True, True, True -> Phone SIM, ESP GPS
          return SosRouteDecision(
            sender: SosSender.PHONE_SIM,
            locationSource: SosLocationSource.ESP_GPS,
          );
        } else {
          // Row 5: True, True, False -> Phone SIM, Phone GPS
          return SosRouteDecision(
            sender: SosSender.PHONE_SIM,
            locationSource: SosLocationSource.PHONE_GPS,
          );
        }
      }
    }
  }
}
