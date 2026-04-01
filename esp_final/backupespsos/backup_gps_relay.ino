/*
  ============================================================================
  BACKUP ESP SOS RELAY FIRMWARE (backup_gps_relay.ino) - SHARED HOTSPOT VERSION
  ============================================================================
  This ESP32 firmware acts as a GPS bridge between the phone and Main ESP:
  1. BLE Server: Receives GPS (LAT/LON) from the "Send GPS" screen in Flutter.
  2. WiFi STA: Connects directly to the Phone Hotspot ("Nothing").
  3. UDP Broadcast: Sends GPS updates to the entire network on Port 4210.
  ============================================================================
*/

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <WiFiUdp.h>

// ---------------- CONFIG ----------------
// Phone Hotspot Credentials
const char* ssid     = "Nothing";
const char* password = "12345678";

// UDP Config
#define UDP_PORT 4210
WiFiUDP udp;

// LED Indicator (GPIO 2 on most ESP32s)
#ifndef LED_BUILTIN
#define LED_BUILTIN 2
#endif
bool ledActive = false;
unsigned long ledStartTime = 0;
#define LED_DURATION 2000

// BLE UUIDs (Standard Nordic UART)
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// ---------------- GLOBALS ----------------
BLEServer* pServer = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
char latestGpsPacket[128] = "LAT:0.000000,LON:0.000000";

// ---------------- BLE CALLBACKS ----------------
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("\n[BLE] App Connected!");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("\n[BLE] App Disconnected.");
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue().c_str();
    if (rxValue.length() > 0) {
      Serial.printf("[BLE RX RAW] %s\n", rxValue.c_str());

      String upperVal = rxValue;
      upperVal.toUpperCase();

      if (upperVal.startsWith("LAT:")) {
        strncpy(latestGpsPacket, rxValue.c_str(), sizeof(latestGpsPacket) - 1);
        
        // --- UDP BROADCAST ---
        udp.beginPacket(IPAddress(255, 255, 255, 255), UDP_PORT);
        udp.print(rxValue);
        udp.endPacket();
        
        // Trigger LED Feedback
        ledActive = true;
        ledStartTime = millis();
        digitalWrite(LED_BUILTIN, HIGH);
        
        Serial.printf("[RELAY] Success! Broadcasted to network port %d\n", UDP_PORT);
      } else {
        Serial.println("[RELAY] Ignored (doesn't start with LAT:)");
      }
    }
  }
};

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n========================================");
  Serial.println("  SURAKSHA BACKUP RELAY (SHARED HOTSPOT)");
  Serial.println("========================================");

  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LOW);

  // 1. WiFi Setup (STA mode)
  Serial.printf("[WiFi] Connecting to %s...\n", ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    udp.begin(UDP_PORT);
  } else {
    Serial.println("[WiFi] FAILED to connect. Check credentials.");
  }

  // 2. BLE Setup
  BLEDevice::init("Suraksha_GPS");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID_RX, 
                        BLECharacteristic::PROPERTY_WRITE
                      );
  pRxCharacteristic->setCallbacks(new MyCallbacks());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] \"Suraksha_GPS\" Active.");
  Serial.println("========================================\n");
}

// ============================================================================
// LOOP
// ============================================================================
void loop() {
  // --- LED Handler ---
  if (ledActive && (millis() - ledStartTime >= LED_DURATION)) {
    ledActive = false;
    digitalWrite(LED_BUILTIN, LOW);
  }

  // --- WiFi Reconnect ---
  if (WiFi.status() != WL_CONNECTED) {
    static unsigned long lastReconnect = 0;
    if (millis() - lastReconnect >= 10000) {
      lastReconnect = millis();
      WiFi.begin(ssid, password);
    }
  }

  // --- 5-Second Auto GPS Relay ---
  static unsigned long lastAutoRelay = 0;
  if (millis() - lastAutoRelay >= 5000) {
    lastAutoRelay = millis();
    if (WiFi.status() == WL_CONNECTED) {
      udp.beginPacket(IPAddress(255, 255, 255, 255), UDP_PORT);
      udp.print(latestGpsPacket);
      udp.endPacket();
      Serial.printf("[AUTO-RELAY] Sent: %s\n", latestGpsPacket);
    }
  }

  // --- BLE Re-advertise ---
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(20);
}
