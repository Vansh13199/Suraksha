// ============================================================================
// TOUCH PLATE + AWS AMPLIFY SOS SENDER (aluminium_sos.ino)
// ============================================================================
// This ESP32 firmware is dedicated to the Aluminium Tap Sensor.
// 1. Connects to GPS ESP Hotspot ("ESP-GPS").
// 2. Listens for GPS data over UDP on port 4210.
// 3. Detects a touch on the aluminium plate (GPIO 32, ADC1).
// 4. Upon touch, sends a GraphQL request to AWS Amplify to create an SOS session.
// 5. Prints a live tracking link combining the domain and the new SOS session ID.
// ============================================================================

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// ---------------- PINS ----------------
// Using ADC1 (GPIO 32) because Wi-Fi disables ADC2 (GPIO 4)
#define TOUCH_PIN 32
int touchThreshold = 40;
bool currentlyTouched = false;

// ---------------- NETWORKING ----------------
const char* gpsEspSsid     = "ESP-GPS";
const char* gpsEspPassword = "Suraksha@admin";

#define UDP_PORT 4210
WiFiUDP udp;
char udpBuffer[128];
String latestLat = "0.000000";
String latestLon = "0.000000";

// ---------------- AWS AMPLIFY API ----------------
// Replace with the genuine API key from implementation_plan.md if different
const char* appsyncUrl = "https://lmusrzicejbirlza2h6mgzehhe.appsync-api.eu-west-1.amazonaws.com/graphql";
const char* apiKey = "da2-5xdgi45ztzfzvfwecopgsxq37u";

// Anti-spam timer for SOS
unsigned long lastSosTrigger = 0;
#define SOS_COOLDOWN 10000 // 10 seconds between SOS requests

// Simple random UUID generator for session IDs
String generateUUID() {
  String uuid = "";
  char hexChars[] = "0123456789abcdef";
  for (int i = 0; i < 32; i++) {
    if (i == 8 || i == 12 || i == 16 || i == 20) uuid += "-";
    uuid += hexChars[random(16)];
  }
  return uuid;
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n========================================");
  Serial.println("  ALUMINIUM TOUCH SOS MODULE");
  Serial.println("========================================");

  // --- WiFi Connection ---
  Serial.print("[WiFi] Connecting to: ");
  Serial.println(gpsEspSsid);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(gpsEspSsid, gpsEspPassword);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("[WiFi] Connected successfully!");
    Serial.print("[WiFi] IP Address: "); Serial.println(WiFi.localIP());
    
    // Wake up ADC1 Touch Peripheral after Wi-Fi boots
    delay(500);
    touchAttachInterrupt(TOUCH_PIN, [](){}, touchThreshold);
    Serial.println("[TOUCH] Peripheral active.");

    // Start UDP Listener
    udp.begin(UDP_PORT);
    Serial.printf("[UDP] Listening for GPS Data on port %d\n", UDP_PORT);
  } else {
    Serial.println("[WiFi] WARNING: Failed to connect to GPS ESP.");
  }
  
  // Seed random generator for UUIDs
  randomSeed(analogRead(0));
  
  Serial.println("========================================");
  Serial.println("  SYSTEM READY");
  Serial.println("========================================");
}

// ============================================================================
// AWS SOS TRIGGER
// ============================================================================
void triggerAwsSos() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[AWS] Cannot send SOS. WiFi disconnected.");
    return;
  }

  // Generate a random Session ID for this emergency
  String sessionId = generateUUID();
  String timestamp = String(millis()); // Substitute for real ISO time

  Serial.println("\n🌐 [AWS] Sending SOS Session creation request...");

  WiFiClientSecure *client = new WiFiClientSecure;
  if (client) {
    client->setInsecure(); // Bypass SSL certificate validation for AWS
    
    HTTPClient http;
    http.begin(*client, appsyncUrl);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("x-api-key", apiKey);

    // Construct GraphQL Mutation Payload natively to match the exact schema
    // Schema: SOSSession { id: ID!, phoneNumber: String!, isActive: Boolean!, latitude: Float, longitude: Float }
    String payload = "{\"query\":\"mutation CreateSOSSession($input: CreateSOSSessionInput!) { createSOSSession(input: $input) { id } }\",\"variables\":{\"input\":{\"id\":\"" + sessionId + "\",\"phoneNumber\":\"ESP32_TAP\",\"isActive\":true,\"latitude\":" + latestLat + ",\"longitude\":" + latestLon + "}}}";

    Serial.println("[AWS] Sending Payload: " + payload);
    int httpResponseCode = http.POST(payload);

    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.printf("[AWS] HTTP %d Response: %s\n", httpResponseCode, response.c_str());
      
      // Print the tracking link!
      Serial.println("\n🚨 ================= EMERGENCY TRIGGERED ================= 🚨");
      Serial.println("  LIVE TRACKING LINK CREATED:");
      Serial.printf("  👉 https://suraksha.dev-vansh.in/?session=%s 👈\n", sessionId.c_str());
      Serial.printf("  LAST KNOWN LOCATION: %s, %s\n", latestLat.c_str(), latestLon.c_str());
      Serial.println("=============================================================\n");
      
    } else {
      Serial.printf("[AWS] Error sending POST: %s\n", http.errorToString(httpResponseCode).c_str());
      if (httpResponseCode == -1) {
        Serial.println("[AWS] Hint: Connection Refused. Check if your ESP-GPS has internet access!");
      }
    }

    http.end();
    delete client;
  } else {
    Serial.println("[AWS] Error: Could not allocate WiFiClientSecure");
  }
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  
  // --- 1. INSTANT TOUCH DETECTION ---
  int rawTouch = touchRead(TOUCH_PIN);
  
  if (rawTouch < touchThreshold) {
    if (!currentlyTouched) {
      currentlyTouched = true;
      Serial.println("\n🚨 >>> ALUMINIUM TAP DETECTED <<< 🚨");
      
      // Trigger AWS SOS if cooldown has passed
      if (millis() - lastSosTrigger >= SOS_COOLDOWN) {
        lastSosTrigger = millis();
        triggerAwsSos();
      } else {
        Serial.println("[AWS] SOS request cooling down... Please wait.");
      }
    }
  } else {
    if (currentlyTouched) {
      currentlyTouched = false;
      Serial.println(">>> Tap Released <<<");
    }
  }

  // --- 2. CHECK FOR INCOMING UDP GPS ---
  if (WiFi.status() == WL_CONNECTED) {
    int packetSize = udp.parsePacket();
    if (packetSize > 0) {
      int len = udp.read(udpBuffer, sizeof(udpBuffer) - 1);
      if (len > 0) {
        udpBuffer[len] = '\0';
        String data = String(udpBuffer);
        data.trim();
        
        // Parse "LAT:xx.xxxx,LON:yy.yyyy"
        // Example: LAT:28.6139,LON:77.2090
        if (data.startsWith("LAT:")) {
          int commaIndex = data.indexOf(",");
          if (commaIndex != -1) {
            latestLat = data.substring(4, commaIndex);
            
            int lonIndex = data.indexOf("LON:");
            if (lonIndex != -1) {
              latestLon = data.substring(lonIndex + 4);
              Serial.printf("[UDP GPS IN] Updated Location -> LAT: %s, LON: %s\n", 
                            latestLat.c_str(), latestLon.c_str());
            }
          }
        }
      }
    }
  }

  // --- 3. DIAGNOSTICS (Every 5 seconds instead of 1 so console is clean) ---
  static unsigned long lastDebugPrint = 0;
  if (millis() - lastDebugPrint >= 5000) {
    lastDebugPrint = millis();
    Serial.printf("[DIAGNOSTIC] Touch: %d | WiFi: %s | GPS: (%s, %s)\n", 
         rawTouch, 
         (WiFi.status() == WL_CONNECTED) ? "UP" : "DOWN",
         latestLat.c_str(), latestLon.c_str());
  }

  delay(20);
}
