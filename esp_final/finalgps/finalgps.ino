// ============================================================================
// BACKUP ESP SOS FIRMWARE (backup_sos.ino) — MEMORY OPTIMIZED
// ============================================================================
// This ESP32 acts as a companion to the backupesptouch (GPS ESP):
// 1. WiFi STA: Connects to the GPS ESP's hotspot ("ESP-GPS").
// 2. UDP Client: Listens on port 4210 for incoming GPS broadcasts.
// 3. Touch Plate: Multi-tap detection (2=SOS, 3=Activity OFF, 4=Activity ON)
// 4. MAX30102 + MPU6050 for health monitoring + auto-SOS
// ============================================================================
// REQUIRES: Arduino ESP32 Core 2.0.17 (NOT 3.x)
// In Arduino IDE: Tools → Board Manager → esp32 by Espressif → 2.0.17
// Core 2.x provides WiFiClientSecure::setBufferSizes() which reduces
// TLS buffers from 32KB to 6KB, enabling HTTPS with BLE active.
// ============================================================================

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <esp_arduino_version.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Preferences.h>
#include "esp_bt.h"

Preferences preferences;
// --- Use char array instead of String for ownerPhone ---
char ownerPhone[20] = "ESP32_MAIN";

// ---------------- PINS ----------------
#define SDA_PIN 18
#define SCL_PIN 19
#define TOUCH_PIN 32

int touchThreshold = 95;
bool currentlyTouched = false;

// ---------------- MPU6050 ----------------
#define MPU_ADDR 0x68
#define MPU_PWR_MGMT_1 0x6B
#define MPU_ACCEL_XOUT_H 0x3B

// ---------------- MAX30102 ----------------
MAX30105 sensor;

// =======================
// PULSE SENSOR
// =======================
unsigned long lastBeat = 0;
float bpm = 0;

const int N = 8;
float buf[N];
int idx = 0, count = 0;

float avgBpm() {
  float s = 0;
  for (int i = 0; i < count; i++) s += buf[i];
  return (count == 0) ? 0 : (s / count);
}

// =======================
// MOTION VARIABLES
// =======================
float ax_g = 0, ay_g = 0, az_g = 0;
float gx_dps = 0, gy_dps = 0, gz_dps = 0;
float motionScore = 0;
unsigned long lastMotionRead = 0;

bool mpuReadBytes(uint8_t startReg, uint8_t *buf, uint8_t len) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(startReg);
  if (Wire.endTransmission(false) != 0) return false;
  uint8_t got = Wire.requestFrom((int)MPU_ADDR, (int)len);
  if (got != len) return false;
  for (uint8_t i = 0; i < len; i++) buf[i] = Wire.read();
  return true;
}

bool readMPU(float &ax, float &ay, float &az, float &gx, float &gy, float &gz) {
  uint8_t data[14];
  if (!mpuReadBytes(MPU_ACCEL_XOUT_H, data, 14)) return false;
  int16_t rawAx = (int16_t)((data[0] << 8) | data[1]);
  int16_t rawAy = (int16_t)((data[2] << 8) | data[3]);
  int16_t rawAz = (int16_t)((data[4] << 8) | data[5]);
  int16_t rawGx = (int16_t)((data[8] << 8) | data[9]);
  int16_t rawGy = (int16_t)((data[10] << 8) | data[11]);
  int16_t rawGz = (int16_t)((data[12] << 8) | data[13]);
  ax = rawAx / 16384.0f;
  ay = rawAy / 16384.0f;
  az = rawAz / 16384.0f;
  gx = rawGx / 131.0f;
  gy = rawGy / 131.0f;
  gz = rawGz / 131.0f;
  return true;
}

bool mpuWriteByte(uint8_t reg, uint8_t data) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.write(data);
  return (Wire.endTransmission() == 0);
}

// ============================================================================
// NETWORKING CONFIG
// ============================================================================
const char* gpsEspSsid     = "Nothing";
const char* gpsEspPassword = "12345678";

#define UDP_PORT 4210
WiFiUDP udp;
char udpBuffer[80]; // Reduced from 128

// --- Use char arrays instead of Strings for GPS data ---
char latestLat[16] = "00.000000";
char latestLon[16] = "00.000000";

// ---------------- ACTIVITY MODE ----------------
bool activityMode = false;
unsigned long activityEndTime = 0;
unsigned long activityDurationSeconds = 0;

// ---------------- VIBRATION MOTOR ----------------
#define VIBRATION_PIN 13

void vibrateContinuous(unsigned long durationMs) {
  unsigned long start = millis();
  digitalWrite(VIBRATION_PIN, HIGH);
  while(millis() - start < durationMs) {
    sensor.check();
    while(sensor.available()) sensor.nextSample();
    delay(10);
  }
  digitalWrite(VIBRATION_PIN, LOW);
}

void vibratePulse(int times, int onMs, int offMs) {
  for (int i = 0; i < times; i++) {
    unsigned long start = millis();
    digitalWrite(VIBRATION_PIN, HIGH);
    while(millis() - start < onMs) {
      sensor.check(); while(sensor.available()) sensor.nextSample(); delay(10);
    }
    digitalWrite(VIBRATION_PIN, LOW);
    if (i < times - 1) {
      start = millis();
      while(millis() - start < offMs) {
        sensor.check(); while(sensor.available()) sensor.nextSample(); delay(10);
      }
    }
  }
}

// ============================================================================
// BLE CONFIG
// ============================================================================
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic = NULL;
BLECharacteristic* pRxCharacteristic = NULL;
bool bleDeviceConnected = false;
bool bleOldDeviceConnected = false;

class SosServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    bleDeviceConnected = true;
    Serial.println("[BLE] Phone connected");
  }
  void onDisconnect(BLEServer* pServer) {
    bleDeviceConnected = false;
    Serial.println("[BLE] Phone disconnected");
  }
};

class SosRxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    // getValue() returns String — use c_str() for C-string ops
    String rxValue = pCharacteristic->getValue().c_str();
    if (rxValue.length() > 0) {
      const char* rx = rxValue.c_str();
      Serial.printf("[BLE] RX: %s\n", rx);

      if (strncmp(rx, "ACTIVITY:1", 10) == 0) {
        const char* comma = strchr(rx, ',');
        if (comma) {
          const char* secStr = strstr(comma, "SECONDS:");
          if (secStr) {
            activityDurationSeconds = atoi(secStr + 8);
          } else {
            activityDurationSeconds = atoi(comma + 1);
          }
          activityMode = true;
          activityEndTime = millis() + (activityDurationSeconds * 1000);
          Serial.printf("[BLE] Activity ON for %d sec\n", activityDurationSeconds);
          vibratePulse(4, 200, 200);
        }
      }
      else if (strncmp(rx, "ACTIVITY:0", 10) == 0) {
        activityMode = false;
        activityDurationSeconds = 0;
        activityEndTime = 0;
        Serial.println("[BLE] Activity OFF");
        vibratePulse(3, 200, 200);
      }
      else if (strncmp(rx, "SET_PHONE:", 10) == 0) {
        const char* phone = rx + 10;
        strncpy(ownerPhone, phone, sizeof(ownerPhone) - 1);
        ownerPhone[sizeof(ownerPhone) - 1] = '\0';
        // Trim trailing whitespace
        int len = strlen(ownerPhone);
        while (len > 0 && (ownerPhone[len-1] == ' ' || ownerPhone[len-1] == '\n' || ownerPhone[len-1] == '\r')) {
          ownerPhone[--len] = '\0';
        }
        preferences.begin("suraksha", false);
        preferences.putString("phone", ownerPhone);
        preferences.end();
        Serial.printf("[BLE] IDENTITY SYNCED: %s\n", ownerPhone);
        vibratePulse(2, 100, 100);
      }
    }
  }
};

// --- Use const char* instead of String ---
void sendBleNotification(const char* msg) {
  if (bleDeviceConnected && pTxCharacteristic != NULL) {
    pTxCharacteristic->setValue(msg);
    pTxCharacteristic->notify();
    Serial.printf("[BLE] TX: %s\n", msg);
  }
}

// ---------------- AWS API ----------------
const char* restUrl = "https://es0tbyl9y0.execute-api.ap-south-1.amazonaws.com/dev/sos/trigger";
const char* stopUrl = "https://es0tbyl9y0.execute-api.ap-south-1.amazonaws.com/dev/sos/stop";

// ---------------- SOS STATE ----------------
bool sosActive = false;
char lastSessionId[40] = "";

unsigned long lastAutoSosTime = 0;
#define AUTO_SOS_COOLDOWN 60000
unsigned long lastSosTrigger = 0;
#define SOS_COOLDOWN 10000
unsigned long lastSosUpdate = 0;
#define LIVE_UPDATE_COOLDOWN 5000 

// --- UUID generation using hardware RNG ---
void generateUUID(char* out) {
  const char hex[] = "0123456789abcdef";
  for (int i = 0; i < 36; i++) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      out[i] = '-';
    } else if (i == 14) {
      out[i] = '4';
    } else if (i == 19) {
      out[i] = hex[8 + (esp_random() % 4)];
    } else {
      out[i] = hex[esp_random() % 16];
    }
  }
  out[36] = '\0';
}

// --- Stop SOS ---
void stopAwsSos() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[STOP] No WiFi");
    sosActive = false;
    return;
  }

  Serial.printf("[STOP] Notifying AWS for Session: %s\n", lastSessionId);
  vibratePulse(1, 400, 0); 
  sendBleNotification("SOS:STOP");

  WiFiClientSecure client;
  client.setInsecure();
  #if defined(ESP_ARDUINO_VERSION) && (ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0))
    client.setRxBufferSize(4096);
    client.setTxBufferSize(2048);
  #else
    client.setHandshakeTimeout(10);
  #endif

  HTTPClient http;
  http.setTimeout(12000);
  if (http.begin(client, stopUrl)) {
    http.addHeader("Content-Type", "application/json");
    char payload[128];
    snprintf(payload, sizeof(payload), "{\"sessionId\":\"%s\"}", lastSessionId);
    
    int code = http.POST((uint8_t*)payload, strlen(payload));
    Serial.printf("[STOP] HTTP Code: %d\n", code);
    
    if (code == 200) {
      Serial.println("[STOP] ✅ Success: Session Ended on AWS");
    } else if (code == 404) {
      Serial.println("[STOP] ⚠️ Session not found (already stopped?)");
    } else {
      Serial.printf("[STOP] ❌ Error Occurred: %d\n", code);
    }
    http.end();
  }

  sosActive = false;
  Serial.println("[SOS] Stopped Locally");
}

// ============================================================================
// SOS TRIGGER — Simple direct HTTPClient call
// TLS buffers reduced to 4KB+2KB via defines, so 50KB heap is enough.
// ============================================================================
void triggerAwsSos() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[SOS] No WiFi");
    return;
  }

  sosActive = false;
  vibratePulse(2, 200, 200);
  sendBleNotification("SOS:START");

  // Generate a FRESH session ID
  char sessionId[37];
  generateUUID(sessionId);
  strncpy(lastSessionId, sessionId, sizeof(lastSessionId));

  Serial.printf("[MEM] Heap for TLS: %d\n", ESP.getFreeHeap());

  WiFiClientSecure client;
  client.setInsecure();
  
  // Set TLS buffer sizes (Compatible with Core 2.x and 3.x)
  #if defined(ESP_ARDUINO_VERSION) && (ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0))
    client.setRxBufferSize(4096);
    client.setTxBufferSize(2048);
  #else
    client.setHandshakeTimeout(10);
  #endif
  
  client.setTimeout(15);

  HTTPClient http;
  http.setTimeout(15000);
  if (http.begin(client, restUrl)) {
    http.addHeader("Content-Type", "application/json");

    char payload[256];
    snprintf(payload, sizeof(payload),
      "{\"phoneNumber\":\"%s\",\"sessionId\":\"%s\",\"latitude\":%s,\"longitude\":%s}",
      ownerPhone, sessionId, latestLat, latestLon);

    Serial.printf("[SOS] Sending (%d bytes)\n", strlen(payload));
    int code = http.POST((uint8_t*)payload, strlen(payload));

    if (code > 0) {
      Serial.printf("[SOS] HTTP %d\n", code);
      if (code == 200) {
        sosActive = true;
        lastSosUpdate = millis(); // Initialize live tracking timer
        Serial.println("\n🚨 EMERGENCY TRIGGERED 🚨");
        Serial.printf("  LINK: https://suraksha.dev-vansh.in/?session=%s\n", sessionId);
        Serial.printf("  GPS: %s, %s\n", latestLat, latestLon);
      }
    } else {
      Serial.printf("[SOS] Error: %s\n", http.errorToString(code).c_str());
    }
    http.end();
  } else {
    Serial.println("[SOS] http.begin FAILED");
  }
}

// ============================================================================
// MULTI-TAP HANDLER
// ============================================================================
const unsigned long TAP_IDLE_MS   = 450;
const unsigned long LONG_PRESS_MS = 5000;

static volatile int tapCount = 0;
static volatile unsigned long lastTapEdgeMs = 0;
static volatile unsigned long touchDownMs = 0;
static volatile bool waitingToFinalize = false;
static volatile int pendingTapAction = 0;
static volatile bool pendingStopAction = false;

// FreeRTOS Task for Touch (Core 0)
void taskTouchSense(void* parameter) {
  while (true) {
    int raw = touchRead(TOUCH_PIN);
    handleTouchFixed(raw);
    vTaskDelay(15 / portTICK_PERIOD_MS); // ~66Hz Scan
  }
}

void handleTouchFixed(int rawTouch) {
  bool isTouch = (rawTouch < touchThreshold);
  unsigned long now = millis();

  // Simple Debounce: only act if state is stable
  static bool lastIsTouch = false;
  static unsigned long lastStableTime = 0;
  if (isTouch != lastIsTouch) {
    lastStableTime = now;
    lastIsTouch = isTouch;
  }

  // Only proceed if state is stable for at least 8ms
  if (now - lastStableTime < 8) return;

  if (isTouch) {
    if (!currentlyTouched) {
      currentlyTouched = true;
      touchDownMs = now;
      tapCount++;
      lastTapEdgeMs = now;
      waitingToFinalize = true;
      Serial.printf("\n🚨 TAP %d (raw=%d)\n", tapCount, rawTouch);
    }
    
    // LONG-PRESS DEACTIVATION (5s)
    if (currentlyTouched) {
      unsigned long heldDuration = now - touchDownMs;
      if (heldDuration >= LONG_PRESS_MS) {
        Serial.println("[TOUCH] 🚨 SOS STOP TRIGGERED (Long Press)");
        pendingStopAction = true; // Set flag for Main Loop (Core 1) to handle
        currentlyTouched = false;
        tapCount = 0;
        waitingToFinalize = false;
        pendingTapAction = 0;
        delay(500); // Prevent accidental re-trigger
        return;
      }
    }
  } else {
    if (currentlyTouched) {
      currentlyTouched = false;
      lastTapEdgeMs = now;
    }
  }

  if (waitingToFinalize && !currentlyTouched && (now - lastTapEdgeMs >= TAP_IDLE_MS)) {
    waitingToFinalize = false;
    Serial.printf("[TOUCH] Finalized: %d taps\n", tapCount);
    if (tapCount == 2) pendingTapAction = 2;
    else if (tapCount == 3) pendingTapAction = 3;
    else if (tapCount >= 4) pendingTapAction = 4;
    tapCount = 0;
  }
}

void processPendingTapAction() {
  if (pendingTapAction == 0) return;
  int action = pendingTapAction;
  pendingTapAction = 0;

  if (action == 2) {
    Serial.println("[TOUCH] 2-tap -> SOS");
    if (millis() - lastSosTrigger >= SOS_COOLDOWN) {
      lastSosTrigger = millis();
      triggerAwsSos();
    } else {
      Serial.println("[AWS] Cooldown...");
    }
  }
  else if (action == 3) {
    Serial.println("[TOUCH] 3-tap -> Activity OFF");
    activityMode = false;
    activityDurationSeconds = 0;
    activityEndTime = 0;
    sendBleNotification("ACTIVITY:DISABLED");
    vibratePulse(3, 200, 200);
  }
  else if (action == 4) {
    Serial.println("[TOUCH] 4-tap -> Activity ON");
    activityMode = true;
    if (activityDurationSeconds > 0) {
      activityEndTime = millis() + (activityDurationSeconds * 1000UL);
    } else {
      activityEndTime = 0;
    }
    sendBleNotification("ACTIVITY:ENABLED");
    vibratePulse(4, 200, 200);
  }
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(300);

  Serial.println("\n========================================");
  Serial.println("  SURAKSHA SOS — MEMORY OPTIMIZED");
  Serial.println("========================================");

  pinMode(VIBRATION_PIN, OUTPUT);
  digitalWrite(VIBRATION_PIN, LOW);

  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000);

  // MAX30102 init
  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found!");
    while (1) delay(10);
  }
  sensor.setup(0xFF, 8, 2, 200, 411, 16384);
  sensor.setPulseAmplitudeIR(0xFF);
  sensor.setPulseAmplitudeRed(0x4F);
  sensor.setPulseAmplitudeGreen(0);

  // MPU6050 init
  if (!mpuWriteByte(MPU_PWR_MGMT_1, 0x00)) {
    Serial.println("MPU6050 not found!");
    while (1) delay(10);
  }

  Serial.println("Sensors OK: MAX30102 + MPU6050");
  Serial.printf("[TOUCH] Reading: %d, Threshold: %d\n", touchRead(TOUCH_PIN), touchThreshold);

  randomSeed(analogRead(0));

  // Load saved identity
  preferences.begin("suraksha", true);
  String savedPhone = preferences.getString("phone", "ESP32_MAIN");
  strncpy(ownerPhone, savedPhone.c_str(), sizeof(ownerPhone) - 1);
  ownerPhone[sizeof(ownerPhone) - 1] = '\0';
  preferences.end();
  Serial.printf("[STORAGE] Owner: %s\n", ownerPhone);

  // WiFi
  Serial.printf("[WiFi] Connecting to %s\n", gpsEspSsid);
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
    Serial.print("[WiFi] IP: "); Serial.println(WiFi.localIP());
    delay(500);
    touchAttachInterrupt(TOUCH_PIN, [](){}, touchThreshold);
    udp.begin(UDP_PORT);
    Serial.printf("[UDP] Port %d\n", UDP_PORT);
  } else {
    Serial.println("[WiFi] FAILED");
  }

  // --- CRITICAL: Release Classic BT memory BEFORE BLE init ---
  // We only use BLE, not Classic BT. This permanently frees ~30KB.
  esp_bt_controller_mem_release(ESP_BT_MODE_CLASSIC_BT);
  Serial.printf("[MEM] After Classic BT release: %d bytes\n", ESP.getFreeHeap());

  // BLE init
  BLEDevice::init("Suraksha_SOS");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new SosServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pTxCharacteristic = pService->createCharacteristic(CHARACTERISTIC_UUID_TX, BLECharacteristic::PROPERTY_NOTIFY);
  pTxCharacteristic->addDescriptor(new BLE2902());
  pRxCharacteristic = pService->createCharacteristic(CHARACTERISTIC_UUID_RX, BLECharacteristic::PROPERTY_WRITE);
  pRxCharacteristic->setCallbacks(new SosRxCallbacks());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
  Serial.println("[BLE] Advertising");

  // Create Background Touch Task (Core 0)
  xTaskCreatePinnedToCore(taskTouchSense, "TouchTask", 2048, NULL, 5, NULL, 0);
  Serial.println("[SYSTEM] Touch Task Pinned to Core 0");

  Serial.printf("[MEM] Free heap at start: %d bytes\n", ESP.getFreeHeap());
  Serial.println("========================================");
  Serial.println("  SYSTEM READY");
  Serial.println("========================================");
}

// ============================================================================
// GPS RECEPTION (UDP)
// ============================================================================
void checkUdpGps() {
  if (WiFi.status() != WL_CONNECTED) return;
  
  int packetSize = udp.parsePacket();
  if (packetSize > 0) {
    int len = udp.read(udpBuffer, sizeof(udpBuffer) - 1);
    if (len > 0) {
      udpBuffer[len] = '\0';
      char* latPtr = strstr(udpBuffer, "LAT:");
      char* lonPtr = strstr(udpBuffer, "LON:");
      if (latPtr && lonPtr) {
        char* comma = strchr(latPtr, ',');
        if (comma) {
          int latLen = comma - (latPtr + 4);
          if (latLen > 0 && latLen < 16) {
            strncpy(latestLat, latPtr + 4, latLen);
            latestLat[latLen] = '\0';
          }
          strncpy(latestLon, lonPtr + 4, 15);
          latestLon[15] = '\0';
          char* nl = strchr(latestLon, '\n');
          if (nl) *nl = '\0';
          nl = strchr(latestLon, '\r');
          if (nl) *nl = '\0';
          
          Serial.printf("📍 GPS SYNC [%lu]: %s, %s\n", millis(), latestLat, latestLon);
        }
      }
      else if (strncmp(udpBuffer, "ACTIVITY:1", 10) == 0) {
        // Handling Activity commands via UDP
        char* comma = strchr(udpBuffer, ',');
        if (comma) {
          char* secStr = strstr(comma, "SECONDS:");
          if (secStr) {
            activityDurationSeconds = atoi(secStr + 8);
            activityMode = true;
            activityEndTime = millis() + (activityDurationSeconds * 1000);
            Serial.printf("[ACTIVITY] ON for %d sec\n", activityDurationSeconds);
          }
        }
      }
      else if (strncmp(udpBuffer, "ACTIVITY:0", 10) == 0) {
        activityMode = false;
        activityDurationSeconds = 0;
        activityEndTime = 0;
        Serial.println("[ACTIVITY] OFF");
      }
    }
  }
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  // BLE re-advertising
  if (!bleDeviceConnected && bleOldDeviceConnected) {
    delay(100);
    pServer->startAdvertising();
    bleOldDeviceConnected = bleDeviceConnected;
  }
  if (bleDeviceConnected && !bleOldDeviceConnected) {
    bleOldDeviceConnected = bleDeviceConnected;
  }

  // Activity timeout
  if (activityMode && activityEndTime > 0 && millis() >= activityEndTime) {
    activityMode = false;
    activityDurationSeconds = 0;
    Serial.println("[ACTIVITY] Expired");
  }

  // MANUAL SERIAL OVERRIDE
  if (Serial.available()) {
    char cmd = Serial.read();
    if (cmd == 's') { 
      Serial.println("[DEBUG] Manual Start Command Received");
      triggerAwsSos(); 
    }
    if (cmd == 'x') { 
      Serial.println("[DEBUG] Manual Stop Command Received");
      stopAwsSos(); 
    }
  }

  // 1-second trace/debug print
  static unsigned long lastDebugPrint = 0;
  if (millis() - lastDebugPrint >= 1000) {
    lastDebugPrint = millis();
    int wifi = (WiFi.status() == WL_CONNECTED);
    if (sosActive) {
      int nextUpdate = (LIVE_UPDATE_COOLDOWN - (millis() - lastSosUpdate)) / 1000;
      if (nextUpdate < 0) nextUpdate = 0;
      Serial.printf("[SYSTEM] WiFi:%d | SOS:1 | HEAP:%d | 📍 NEXT UPDATE: %ds\n", wifi, ESP.getFreeHeap(), nextUpdate);
    }
  }

  // Touch detection is now handled by Core 0 Background Task
  // We only process the actions in the main loop (Core 1)
  processPendingTapAction();

  // Safe Cloud Stop Execution (Decoupled from Core 0)
  if (pendingStopAction) {
    pendingStopAction = false;
    stopAwsSos();
  }

  // Check UDP for new GPS
  checkUdpGps();

  // --- LIVE SOS UPDATE (Main Loop) ---
  if (sosActive && (millis() - lastSosUpdate >= LIVE_UPDATE_COOLDOWN)) {
    lastSosUpdate = millis();
    Serial.println("[LIVE] 🚀 Sending Update to AWS...");
    
    WiFiClientSecure client; client.setInsecure();
    #if defined(ESP_ARDUINO_VERSION) && (ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0))
      client.setRxBufferSize(4096); client.setTxBufferSize(2048);
    #else
      client.setHandshakeTimeout(10);
    #endif
    
    HTTPClient http; http.setTimeout(8000); 
    if (http.begin(client, restUrl)) {
      http.addHeader("Content-Type", "application/json");
      char payload[256];
      snprintf(payload, sizeof(payload),
        "{\"phoneNumber\":\"%s\",\"sessionId\":\"%s\",\"latitude\":%s,\"longitude\":%s}",
        ownerPhone, lastSessionId, latestLat, latestLon);
      int code = http.POST((uint8_t*)payload, strlen(payload));
      if (code == 200) Serial.println("[LIVE] ✅ Success: Map Updated");
      else Serial.printf("[LIVE] ❌ Error: %d\n", code);
      http.end();
    }
  }

  // Motion read at ~50Hz
  if (millis() - lastMotionRead >= 20) {
    lastMotionRead = millis();
    if (readMPU(ax_g, ay_g, az_g, gx_dps, gy_dps, gz_dps)) {
      float accMag = sqrtf(ax_g * ax_g + ay_g * ay_g + az_g * az_g);
      float accDelta = fabsf(accMag - 1.0f);
      float gyroMag = sqrtf(gx_dps * gx_dps + gy_dps * gy_dps + gz_dps * gz_dps);
      float scoreNow = accDelta + (gyroMag / 200.0f);
      motionScore = motionScore * 0.85f + scoreNow * 0.15f;
    }
  }

  // Pulse sensor loop
  sensor.check();
  uint32_t innerStart = millis();
  while (sensor.available() && (millis() - innerStart < 50)) {
    // Background Task on Core 0 is handling touch for us!
    processPendingTapAction();

    long ir = sensor.getIR();
    sensor.nextSample();

    if (ir < 20000) {
      count = 0; idx = 0;
      continue;
    }

    if (checkForBeat(ir)) {
      unsigned long now = millis();
      unsigned long dt = now - lastBeat;
      lastBeat = now;
      if (dt > 250 && dt < 2000) {
        bpm = 60.0f / (dt / 1000.0f);
        if (bpm >= 35 && bpm <= 200) {
          buf[idx] = bpm;
          idx = (idx + 1) % N;
          if (count < N) count++;
          Serial.printf("BPM=%.1f MOTION=%.3f ACT=%d\n", avgBpm(), motionScore, activityMode);

          // Auto-SOS on abnormal HR
          if (!sosActive && !activityMode && (millis() - lastAutoSosTime >= AUTO_SOS_COOLDOWN)) {
            float currentBpm = avgBpm();
            if (currentBpm > 0 && (currentBpm < 40 || currentBpm > 140)) {
              Serial.printf("\n🚨 AUTO-SOS: BPM=%.1f\n", currentBpm);
              lastAutoSosTime = millis();
              triggerAwsSos();
              sosActive = true;
            }
          }
        }
      }
    }
  }
  delay(10);
}
