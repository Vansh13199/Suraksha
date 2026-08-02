// ============================================================================
// SURAKSHA SOS — MINIMAL PUSH BUTTON TEST (Virtual ESP32)
// ============================================================================
// GPIO 4 Push Button:
//   SHORT PRESS  → Trigger SOS (sends HTTPS POST to AWS)
//   LONG PRESS (3s) → Stop active SOS session
//
// This is a stripped-down version for virtual ESP32 testing.
// No BLE, no sensors, no touch plate — just WiFi + Button + AWS API.
// ============================================================================

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// ===================== CONFIGURATION =====================

// WiFi Credentials (change to your network / virtual env AP)
const char* WIFI_SSID     = "Nothing";
const char* WIFI_PASSWORD = "12345678";

// AWS API Endpoints (same as production firmware)
const char* SOS_TRIGGER_URL = "https://3argzpovmc.execute-api.ap-south-1.amazonaws.com/prod/sos/trigger";
const char* SOS_STOP_URL    = "https://3argzpovmc.execute-api.ap-south-1.amazonaws.com/prod/sos/stop";

// Owner Phone Number — the phone number registered in DynamoDB User table.
// The backend uses this to look up the user and find their emergency contacts.
// ⚠️ CHANGE THIS to your actual registered phone number (with country code).
const char* OWNER_PHONE = "+918837578715";

// Dummy GPS coordinates (no GPS module in virtual env)
const char* DEFAULT_LAT = "28.613900";
const char* DEFAULT_LON = "77.209000";

// ===================== BUTTON CONFIG =====================

#define BUTTON_PIN        4
#define DEBOUNCE_MS       50      // Debounce window
#define LONG_PRESS_MS     3000    // 3 seconds = STOP SOS
#define SOS_COOLDOWN_MS   10000   // Prevent re-trigger within 10s

// ===================== STATE =====================

bool sosActive = false;
char lastSessionId[40] = "";

// Button state machine
bool lastButtonState   = HIGH;   // INPUT_PULLUP: HIGH = released
bool buttonState       = HIGH;
unsigned long lastDebounceTime  = 0;
unsigned long buttonPressStart  = 0;
bool buttonHandled     = false;  // Prevents repeated triggers while held

// Cooldown
unsigned long lastSosTriggerTime = 0;

// WiFi reconnect
unsigned long lastWifiCheck = 0;
#define WIFI_CHECK_INTERVAL 5000

// Status print
unsigned long lastStatusPrint = 0;

// ===================== UUID GENERATOR =====================

void generateUUID(char* out) {
  const char hex[] = "0123456789abcdef";
  for (int i = 0; i < 36; i++) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      out[i] = '-';
    } else if (i == 14) {
      out[i] = '4';  // UUID v4
    } else if (i == 19) {
      out[i] = hex[8 + (esp_random() % 4)];
    } else {
      out[i] = hex[esp_random() % 16];
    }
  }
  out[36] = '\0';
}

// ===================== WIFI HELPERS =====================

bool connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return true;

  Serial.printf("[WiFi] Connecting to %s...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] ✅ Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    return true;
  } else {
    Serial.println("[WiFi] ❌ Connection failed");
    return false;
  }
}

void ensureWiFi() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Lost connection, reconnecting...");
    WiFi.disconnect();
    delay(100);
    connectWiFi();
  }
}

// ===================== SOS TRIGGER =====================

void triggerSos() {
  Serial.println("\n🚨 ========== SOS TRIGGER ==========");

  if (sosActive) {
    Serial.println("[SOS] ⚠️ Already active! Use long-press to stop first.");
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[SOS] ❌ No WiFi — cannot send SOS");
    // Try to reconnect
    if (!connectWiFi()) {
      Serial.println("[SOS] ❌ WiFi reconnect failed. SOS NOT sent.");
      return;
    }
  }

  // Cooldown check
  if (millis() - lastSosTriggerTime < SOS_COOLDOWN_MS) {
    unsigned long remaining = (SOS_COOLDOWN_MS - (millis() - lastSosTriggerTime)) / 1000;
    Serial.printf("[SOS] ⏳ Cooldown active. Wait %lu more seconds.\n", remaining);
    return;
  }

  // Generate fresh session ID
  char sessionId[37];
  generateUUID(sessionId);
  strncpy(lastSessionId, sessionId, sizeof(lastSessionId));
  lastSessionId[sizeof(lastSessionId) - 1] = '\0';

  Serial.printf("[SOS] Session: %s\n", sessionId);
  Serial.printf("[SOS] Phone:   %s\n", OWNER_PHONE);
  Serial.printf("[SOS] GPS:     %s, %s (default/dummy)\n", DEFAULT_LAT, DEFAULT_LON);
  Serial.printf("[MEM] Free heap: %d bytes\n", ESP.getFreeHeap());

  // HTTPS POST
  WiFiClientSecure client;
  client.setInsecure();  // Skip cert verification (acceptable for testing)
  client.setTimeout(15);

  HTTPClient http;
  http.setTimeout(15000);

  if (!http.begin(client, SOS_TRIGGER_URL)) {
    Serial.println("[SOS] ❌ http.begin() failed");
    return;
  }

  http.addHeader("Content-Type", "application/json");

  char payload[320];
  snprintf(payload, sizeof(payload),
    "{\"phoneNumber\":\"%s\",\"sessionId\":\"%s\",\"latitude\":%s,\"longitude\":%s,\"heartRate\":0}",
    OWNER_PHONE, sessionId, DEFAULT_LAT, DEFAULT_LON);

  Serial.printf("[SOS] Payload: %s\n", payload);

  int httpCode = http.POST((uint8_t*)payload, strlen(payload));

  if (httpCode > 0) {
    String response = http.getString();
    Serial.printf("[SOS] HTTP %d\n", httpCode);
    Serial.printf("[SOS] Response: %s\n", response.c_str());

    if (httpCode == 200) {
      sosActive = true;
      lastSosTriggerTime = millis();
      Serial.println("\n🚨🚨🚨 EMERGENCY SOS ACTIVATED 🚨🚨🚨");
      Serial.printf("  📍 Track: https://suraksha.dev-vansh.in/?session=%s\n", sessionId);
      Serial.println("  ℹ️  Long-press button (3s) to STOP SOS");
    } else {
      Serial.printf("[SOS] ❌ Server returned error code: %d\n", httpCode);
    }
  } else {
    Serial.printf("[SOS] ❌ HTTP Error: %s\n", http.errorToString(httpCode).c_str());
  }

  http.end();
  Serial.println("====================================\n");
}

// ===================== SOS STOP =====================

void stopSos() {
  Serial.println("\n🛑 ========== SOS STOP ==========");

  if (!sosActive) {
    Serial.println("[STOP] ⚠️ No active SOS session to stop.");
    return;
  }

  if (strlen(lastSessionId) == 0) {
    Serial.println("[STOP] ⚠️ No session ID stored. Clearing state.");
    sosActive = false;
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[STOP] ❌ No WiFi — stopping locally only");
    sosActive = false;
    Serial.println("[STOP] ✅ SOS stopped locally (AWS not notified)");
    return;
  }

  Serial.printf("[STOP] Ending session: %s\n", lastSessionId);

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.setTimeout(12000);

  if (!http.begin(client, SOS_STOP_URL)) {
    Serial.println("[STOP] ❌ http.begin() failed");
    sosActive = false;
    return;
  }

  http.addHeader("Content-Type", "application/json");

  char payload[128];
  snprintf(payload, sizeof(payload), "{\"sessionId\":\"%s\"}", lastSessionId);

  int httpCode = http.POST((uint8_t*)payload, strlen(payload));

  if (httpCode > 0) {
    String response = http.getString();
    Serial.printf("[STOP] HTTP %d\n", httpCode);
    Serial.printf("[STOP] Response: %s\n", response.c_str());

    if (httpCode == 200) {
      Serial.println("[STOP] ✅ SOS session ended on AWS");
    } else if (httpCode == 404) {
      Serial.println("[STOP] ⚠️ Session not found (already expired?)");
    } else {
      Serial.printf("[STOP] ❌ Server error: %d\n", httpCode);
    }
  } else {
    Serial.printf("[STOP] ❌ HTTP Error: %s\n", http.errorToString(httpCode).c_str());
  }

  http.end();
  sosActive = false;
  memset(lastSessionId, 0, sizeof(lastSessionId));
  Serial.println("==================================\n");
}

// ===================== BUTTON HANDLER =====================
// Debounced button with short-press (SOS) and long-press (STOP)

void handleButton() {
  bool reading = digitalRead(BUTTON_PIN);

  // Reset debounce timer on state change
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }
  lastButtonState = reading;

  // Only act after stable for DEBOUNCE_MS
  if ((millis() - lastDebounceTime) < DEBOUNCE_MS) return;

  // Detect press edge (HIGH → LOW because INPUT_PULLUP)
  if (reading == LOW && buttonState == HIGH) {
    // Button just pressed
    buttonState = LOW;
    buttonPressStart = millis();
    buttonHandled = false;
    Serial.println("[BTN] Pressed ▼");
  }

  // While button is held down, check for long press
  if (buttonState == LOW && reading == LOW && !buttonHandled) {
    unsigned long held = millis() - buttonPressStart;
    if (held >= LONG_PRESS_MS) {
      // LONG PRESS → Stop SOS
      Serial.printf("[BTN] Long press detected (%lu ms)\n", held);
      buttonHandled = true;
      stopSos();
    }
  }

  // Detect release edge (LOW → HIGH)
  if (reading == HIGH && buttonState == LOW) {
    unsigned long held = millis() - buttonPressStart;
    buttonState = HIGH;
    Serial.printf("[BTN] Released ▲ (held %lu ms)\n", held);

    // SHORT PRESS → Trigger SOS (only if not already handled as long press)
    if (!buttonHandled && held < LONG_PRESS_MS) {
      triggerSos();
    }
    buttonHandled = false;
  }
}

// ===================== SERIAL COMMANDS =====================
// For testing without a physical/virtual button

void handleSerialCommands() {
  if (!Serial.available()) return;

  char cmd = Serial.read();
  // Flush remaining chars in the line
  while (Serial.available()) Serial.read();

  switch (cmd) {
    case 's':
    case 'S':
      Serial.println("[SERIAL] Manual SOS trigger");
      triggerSos();
      break;
    case 'x':
    case 'X':
      Serial.println("[SERIAL] Manual SOS stop");
      stopSos();
      break;
    case '?':
      Serial.println("\n─── COMMANDS ───");
      Serial.println("  s = Trigger SOS");
      Serial.println("  x = Stop SOS");
      Serial.println("  ? = Show help");
      Serial.printf("  Status: SOS=%s, WiFi=%s\n",
        sosActive ? "ACTIVE" : "OFF",
        WiFi.status() == WL_CONNECTED ? "OK" : "DISCONNECTED");
      if (sosActive) {
        Serial.printf("  Session: %s\n", lastSessionId);
      }
      Serial.println("────────────────\n");
      break;
    default:
      break;
  }
}

// ===================== SETUP =====================

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println("\n========================================");
  Serial.println("  SURAKSHA SOS — BUTTON TEST");
  Serial.println("  (Virtual ESP32 Environment)");
  Serial.println("========================================");
  Serial.printf("  Button Pin : GPIO %d (INPUT_PULLUP)\n", BUTTON_PIN);
  Serial.printf("  Owner Phone: %s\n", OWNER_PHONE);
  Serial.printf("  Default GPS: %s, %s\n", DEFAULT_LAT, DEFAULT_LON);
  Serial.println("========================================\n");

  // Button setup
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  // Seed RNG for UUID generation
  randomSeed(analogRead(0));

  // Connect WiFi
  connectWiFi();

  Serial.println("\n─── CONTROLS ───");
  Serial.println("  SHORT PRESS  → Trigger SOS");
  Serial.println("  LONG PRESS (3s) → Stop SOS");
  Serial.println("  Serial: 's'=SOS, 'x'=Stop, '?'=Status");
  Serial.printf("  Free heap: %d bytes\n", ESP.getFreeHeap());
  Serial.println("─────────────────\n");
  Serial.println("[SYSTEM] ✅ Ready. Waiting for button press...\n");
}

// ===================== LOOP =====================

void loop() {
  // 1. Handle button (debounced, short/long press)
  handleButton();

  // 2. Handle serial commands (for testing)
  handleSerialCommands();

  // 3. Periodic WiFi health check & reconnect
  if (millis() - lastWifiCheck >= WIFI_CHECK_INTERVAL) {
    lastWifiCheck = millis();
    ensureWiFi();
  }

  // 4. Periodic status print (every 5 seconds)
  if (millis() - lastStatusPrint >= 5000) {
    lastStatusPrint = millis();
    bool wifiOk = (WiFi.status() == WL_CONNECTED);

    if (sosActive) {
      Serial.printf("[STATUS] 🚨 SOS ACTIVE | WiFi:%s | Session:%s | Heap:%d\n",
        wifiOk ? "✅" : "❌", lastSessionId, ESP.getFreeHeap());
    } else {
      Serial.printf("[STATUS] ✅ Idle | WiFi:%s | Heap:%d\n",
        wifiOk ? "✅" : "❌", ESP.getFreeHeap());
    }
  }

  // Small delay to prevent CPU hogging in virtual env
  delay(10);
}