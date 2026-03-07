// ============================================================================
// BACKUP ESP SOS FIRMWARE (backup_sos.ino)
// ============================================================================
// This ESP32 acts as a companion to the backupesptouch (GPS ESP):
// 1. WiFi STA: Connects to the GPS ESP's hotspot ("ESP-GPS").
// 2. UDP Client: Listens on port 4210 for incoming GPS broadcasts.
// 3. Touch Plate: Extremely sensitive (no strict threshold logic) — prints
//    "TOUCHED" immediately to the console upon any contact.
// ============================================================================

#include <WiFi.h>
#include <WiFiUdp.h>

// ============================================================================
// TOUCH PLATE CONFIG
// ============================================================================
// Pin 4 corresponds to Touch0 on the ESP32
#define TOUCH_PIN 4

// In setup(), we take a baseline reading. Any sudden drop from the baseline 
// is treated as a touch instantly.
int touchBaseline = 0;
bool currentlyTouched = false;

// ============================================================================
// NETWORKING CONFIG (Connects to GPS ESP)
// ============================================================================
const char* gpsEspSsid     = "ESP-GPS";
const char* gpsEspPassword = "Suraksha@admin";

#define UDP_PORT 4210
WiFiUDP udp;
char udpBuffer[128];

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);  // Allow serial to settle

  Serial.println("\n\n========================================");
  Serial.println("  BACKUP ESP SOS — INITIALIZING");
  Serial.println("========================================");

  // --- 1. Touch Plate Initialization ---
  // Read a few times to get a stable un-touched baseline purely for reference
  int sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += touchRead(TOUCH_PIN);
    delay(10);
  }
  touchBaseline = sum / 10;
  Serial.printf("[TOUCH] Baseline reading set at: %d (Any sudden drop triggers)\n", touchBaseline);

  // --- 2. WiFi Connection ---
  Serial.print("[WiFi] Connecting to GPS ESP Hotspot: ");
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
    Serial.println("[WiFi] Connected to GPS ESP successfully!");
    Serial.print("[WiFi] IP Address: "); Serial.println(WiFi.localIP());
    
    // Start UDP Listener
    udp.begin(UDP_PORT);
    Serial.printf("[UDP] Listening for GPS Data on port %d\n", UDP_PORT);
  } else {
    Serial.println("[WiFi] WARNING: Failed to connect to GPS ESP.");
  }
  
  Serial.println("========================================");
  Serial.println("  SYSTEM READY");
  Serial.println("========================================");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  
  // --- 1. INSTANT TOUCH DETECTION ---
  // ESP32 touch pins normally read ~70-90 in air.
  // When touched by skin, they immediately drop.
  // We use a dynamic threshold just slighty below the baseline to catch ANYTHING.
  
  int rawTouch = touchRead(TOUCH_PIN);
  
  // If the raw touch value drops more than 15 points below baseline, it's a confirmed touch.
  // We don't use a hardcoded threshold (like 60) so it works regardless of plate size/material.
  if (rawTouch < (touchBaseline - 15)) {
    if (!currentlyTouched) {
      currentlyTouched = true;
      Serial.println("\n🚨 >>> TOUCHED <<< 🚨");
    }
  } else {
    if (currentlyTouched) {
      currentlyTouched = false;
      Serial.println(">>> Finger Released <<<");
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
        
        Serial.println("┌──────────────────────────────────────┐");
        Serial.print("│ [UDP GPS IN] "); Serial.println(data);
        Serial.println("└──────────────────────────────────────┘");
      }
    }
  }

  delay(20); // Small delay to prevent tight loop instability
}
