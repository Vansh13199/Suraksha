// ============================================================================
// BACKUP ESP SOS FIRMWARE (backup_sos.ino)
// ============================================================================
// This ESP32 acts as a companion to the backupesptouch (GPS ESP):
// 1. WiFi STA: Connects to the GPS ESP's hotspot ("ESP-GPS").
// 2. UDP Client: Listens on port 4210 for incoming GPS broadcasts.
// 3. Touch Plate: Multi-tap detection (FIXED: supports 2 / 3 / 4+ taps reliably)
//    3 taps -> Activity DISABLED
//    4 taps -> Activity ENABLED
// 4. MAX30102 + MPU6050 integrated exactly as requested.
// ============================================================================

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ---------------- PINS ----------------
#define SDA_PIN 18
#define SCL_PIN 19
// CRITICAL FIX: We cannot use GPIO 4 (Touch0, ADC2) because the ESP32 WiFi
// driver monopolizes ADC2. When WiFi is on, touchRead() on ADC2 returns 0!
// We MUST use an ADC1 touch pin to work simultaneously with WiFi.
// Options for ADC1 Touch Pins: GPIO 32 (Touch9) or GPIO 33 (Touch8).
#define TOUCH_PIN 32

// Fixed threshold used in previous versions
int touchThreshold = 40;
bool currentlyTouched = false;

// ---------------- MPU6050 ----------------
#define MPU_ADDR 0x68
#define MPU_PWR_MGMT_1 0x6B
#define MPU_ACCEL_XOUT_H 0x3B

// ---------------- MAX30102 ----------------
MAX30105 sensor;

// =======================
// ✅ PULSE SENSOR CODE (UNCHANGED)
// =======================
unsigned long lastBeat = 0;
float bpm = 0;

// Smooth average
const int N = 8;
float buf[N];
int idx = 0, count = 0;

float avgBpm() {
  float s = 0;
  for (int i = 0; i < count; i++) s += buf[i];
  return (count == 0) ? 0 : (s / count);
}

// =======================
// ✅ MOTION VARIABLES
// =======================
float ax_g = 0, ay_g = 0, az_g = 0;
float gx_dps = 0, gy_dps = 0, gz_dps = 0;
float motionScore = 0;
unsigned long lastMotionRead = 0;

// Read MPU6050 raw data (Accel + Gyro)
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

  // Default sensitivity: accel ±2g => 16384 LSB/g, gyro ±250 => 131 LSB/(°/s)
  ax = rawAx / 16384.0f;
  ay = rawAy / 16384.0f;
  az = rawAz / 16384.0f;

  gx = rawGx / 131.0f;
  gy = rawGy / 131.0f;
  gz = rawGz / 131.0f;

  return true;
}

// MPU write helper
bool mpuWriteByte(uint8_t reg, uint8_t data) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.write(data);
  return (Wire.endTransmission() == 0);
}

// ============================================================================
// NETWORKING CONFIG (Connects to Phone Hotspot)
// ============================================================================
const char* gpsEspSsid     = "Nothing";
const char* gpsEspPassword = "12345678";

#define UDP_PORT 4210
WiFiUDP udp;
char udpBuffer[128];
String latestGpsData = "LAT:0.000000,LON:0.000000";
String latestLat = "0.000000";
String latestLon = "0.000000";

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
    while(sensor.available()) sensor.nextSample(); // Prevent FIFO overflow!
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
// BLE CONFIG (Direct communication with Flutter app)
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
    Serial.println("[BLE] Phone connected to SOS ESP!");
  }
  void onDisconnect(BLEServer* pServer) {
    bleDeviceConnected = false;
    Serial.println("[BLE] Phone disconnected from SOS ESP");
  }
};

class SosRxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();
    if (rxValue.length() > 0) {
      Serial.printf("[BLE] Received from phone: %s\n", rxValue.c_str());

      // Parse ACTIVITY commands from phone
      if (rxValue.startsWith("ACTIVITY:1")) {
        int commaIndex = rxValue.indexOf(",");
        if (commaIndex != -1) {
          String secString = rxValue.substring(commaIndex + 9); // After "SECONDS:"
          activityDurationSeconds = secString.toInt();
          activityMode = true;
          activityEndTime = millis() + (activityDurationSeconds * 1000);
          Serial.printf("[BLE] Activity ENABLED for %d seconds\n", activityDurationSeconds);
          vibratePulse(4, 200, 200); // 4 pulses = activity ON (same as 4-tap feedback)
        }
      }
      else if (rxValue.startsWith("ACTIVITY:0")) {
        activityMode = false;
        activityDurationSeconds = 0;
        activityEndTime = 0;
        Serial.println("[BLE] Activity DISABLED by phone");
        vibratePulse(3, 200, 200); // 3 pulses = activity OFF (same as 3-tap feedback)
      }
    }
  }
};

// Send notification to phone via BLE (replaces UDP relay)
void sendBleNotification(String msg) {
  if (bleDeviceConnected && pTxCharacteristic != NULL) {
    pTxCharacteristic->setValue(msg.c_str());
    pTxCharacteristic->notify();
    Serial.printf("[BLE] Sent to phone: '%s'\n", msg.c_str());
  } else {
    Serial.printf("[BLE] Cannot send '%s' — phone not connected\n", msg.c_str());
  }
}


// ---------------- AWS AMPLIFY API ----------------
const char* appsyncUrl = "https://lmusrzicejbirlza2h6mgzehhe.appsync-api.eu-west-1.amazonaws.com/graphql";
const char* apiKey = "da2-5xdgi45ztzfzvfwecopgsxq37u";

// ---------------- AUTO SOS CONFIG ----------------
bool sosActive = false;
String lastSessionId = "";
unsigned long lastAutoSosTime = 0;
#define AUTO_SOS_COOLDOWN 60000 // 60 seconds

// Anti-spam timer for manual SOS
unsigned long lastSosTrigger = 0;
#define SOS_COOLDOWN 10000 // 10 seconds between SOS requests

// Generates a strict RFC 4122 v4 UUID for AWS Amplify compatibility
// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx (where y is 8, 9, a, or b)
String generateUUID() {
  String uuid = "";
  char hexChars[] = "0123456789abcdef";
  for (int i = 0; i < 36; i++) {
    if (i == 8 || i == 13 || i == 18 || i == 23) {
      uuid += "-";
    } else if (i == 14) {
      uuid += "4"; // UUID version 4
    } else if (i == 19) {
      uuid += hexChars[random(8, 12)]; // 'y' must be 8, 9, A, or B
    } else {
      uuid += hexChars[random(16)];
    }
  }
  return uuid;
}

// Optional implementation for Long Press requirement
void stopAwsSos() {
  Serial.println("[AWS] Stopping SOS...");
  vibrateContinuous(3000);
  sendBleNotification("SOS:STOP");

  // Update AppSync to set isActive=false
  if (lastSessionId.length() > 0 && WiFi.status() == WL_CONNECTED) {
    Serial.printf("[AWS] Deactivating session: %s\n", lastSessionId.c_str());
    BLEDevice::deinit(false);
    delay(100);

    WiFiClientSecure *client = new WiFiClientSecure;
    if (client) {
      client->setInsecure();
      HTTPClient http;
      http.begin(*client, appsyncUrl);
      http.addHeader("Content-Type", "application/json");
      http.addHeader("x-api-key", apiKey);

      String payload = "{\"query\":\"mutation UpdateSOSSession($input: UpdateSOSSessionInput!) { updateSOSSession(input: $input) { id isActive } }\",\"variables\":{\"input\":{\"id\":\"" + lastSessionId + "\",\"isActive\":false}}}";
      Serial.println("[AWS] Stop Payload: " + payload);
      int code = http.POST(payload);
      if (code > 0) {
        Serial.printf("[AWS] Stop response HTTP %d: %s\n", code, http.getString().c_str());
      } else {
        Serial.printf("[AWS] Stop error: %s\n", http.errorToString(code).c_str());
      }
      http.end();
      delete client;
    }
    lastSessionId = "";
    reinitBLE();
  } else {
    Serial.println("[AWS] No active session to stop or WiFi disconnected");
  }
}
// ============================================================================
// Helper: Reinitialize BLE server after temporary shutdown

void reinitBLE() {

  Serial.println("[BLE] Restarting BLE server...");

  BLEDevice::init("Suraksha_SOS");

  pServer = BLEDevice::createServer();

  pServer->setCallbacks(new SosServerCallbacks());

  BLEService *pSvc = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pSvc->createCharacteristic(CHARACTERISTIC_UUID_TX, BLECharacteristic::PROPERTY_NOTIFY);

  pTxCharacteristic->addDescriptor(new BLE2902());

  pRxCharacteristic = pSvc->createCharacteristic(CHARACTERISTIC_UUID_RX, BLECharacteristic::PROPERTY_WRITE);

  pRxCharacteristic->setCallbacks(new SosRxCallbacks());

  pSvc->start();

  BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);

  BLEDevice::startAdvertising();

  bleDeviceConnected = false;

  bleOldDeviceConnected = false;

  Serial.println("[BLE] BLE restarted and advertising");

}



// AWS SOS TRIGGER
// ============================================================================
void triggerAwsSos() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[AWS] Cannot send SOS. WiFi disconnected.");
    return;
  }

  // --- NEW VIBRATION REQUIREMENT ---
  vibrateContinuous(2000);
  vibratePulse(2, 200, 200);
  sendBleNotification("SOS:START");

  // --- SAFEGUARD: WAIT FOR LEGITIMATE GPS COORDINATES BEFORE SENDING ---
  if (latestLat == "0.000000" || latestLat == "0.0") {
    Serial.println("[AWS] WARNING: Location is 0.000000! Waiting for valid UDP GPS burst...");
    unsigned long waitStart = millis();

    // Wait up to 10 seconds for valid GPS coordinates to arrive from the GPS ESP
    while ((latestLat == "0.000000" || latestLat == "0.0") && (millis() - waitStart < 10000)) {
      int packetSize = udp.parsePacket();
      if (packetSize > 0) {
        int len = udp.read(udpBuffer, sizeof(udpBuffer) - 1);
        if (len > 0) {
          udpBuffer[len] = '\0';
          String data = String(udpBuffer);
          data.trim();
          latestGpsData = data;

          if (data.startsWith("LAT:")) {
            int commaIndex = data.indexOf(",");
            if (commaIndex != -1) {
              latestLat = data.substring(4, commaIndex);
              int lonIndex = data.indexOf("LON:");
              if (lonIndex != -1) {
                latestLon = data.substring(lonIndex + 4);
              }
            }
          }
        }
      }
      delay(100); // Give ESP network stack time to breathe
    }

    if (latestLat == "0.000000" || latestLat == "0.0") {
      Serial.println("[AWS] ERROR: Timed out waiting for GPS. Sending SOS with 0.000000 to save life anyway.");
    } else {
      Serial.printf("[AWS] GPS Acquired! %s, %s\n", latestLat.c_str(), latestLon.c_str());
    }
  }

  String sessionId = generateUUID();
  lastSessionId = sessionId;
  Serial.println("\n🌐 [AWS] Sending SOS Session creation request...");

  // Free RAM: Stop BLE temporarily for SSL handshake

  Serial.printf("[MEM] Free heap: %d bytes\n", ESP.getFreeHeap());

  BLEDevice::deinit(false);

  delay(100);

  Serial.printf("[MEM] Free heap after BLE stop: %d bytes\n", ESP.getFreeHeap());



  WiFiClientSecure *client = new WiFiClientSecure;
  if (client) {
    client->setInsecure(); // Bypass SSL certificate validation for AWS

    HTTPClient http;
    http.begin(*client, appsyncUrl);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("x-api-key", apiKey);

    // Schema: SOSSession { id: ID!, phoneNumber: String!, isActive: Boolean!, latitude: Float, longitude: Float }
    String payload = "{\"query\":\"mutation CreateSOSSession($input: CreateSOSSessionInput!) { createSOSSession(input: $input) { id } }\",\"variables\":{\"input\":{\"id\":\"" + sessionId + "\",\"phoneNumber\":\"ESP32_MAIN\",\"isActive\":true,\"latitude\":" + latestLat + ",\"longitude\":" + latestLon + "}}}";

    Serial.println("[AWS] Sending Payload: " + payload);
    int httpResponseCode = http.POST(payload);

    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.printf("[AWS] HTTP %d Response: %s\n", httpResponseCode, response.c_str());

      Serial.println("\n🚨 ================= EMERGENCY TRIGGERED ================= 🚨");
      Serial.println("  LIVE TRACKING LINK CREATED:");
      Serial.printf("  👉 https://suraksha.dev-vansh.in/?session=%s 👈\n", sessionId.c_str());
      Serial.println("     (Or test locally at: http://localhost:5173/?session=" + sessionId + ")");
      Serial.printf("  LAST KNOWN LOCATION: %s, %s\n", latestLat.c_str(), latestLon.c_str());
      Serial.println("=============================================================\n");
    } else {
      Serial.printf("[AWS] Error sending POST: %s\n", http.errorToString(httpResponseCode).c_str());
    }

    http.end();
    delete client;
  }


  // Restart BLE after HTTPS call

  reinitBLE();

}

// ============================================================================
// ✅ MULTI-TAP FIX (ONLY CHANGE): finalize taps after silence, not after first tap
// ============================================================================
const unsigned long TAP_IDLE_MS   = 550;   // finalize after 550ms of no new tap
const unsigned long LONG_PRESS_MS = 5000;

static int tapCount = 0;
static unsigned long lastTapEdgeMs = 0;
static unsigned long touchDownMs = 0;
static bool waitingToFinalize = false;

// Run actions outside the touch handler (so 3/4 taps don't get blocked by SOS)
static int pendingTapAction = 0; // 0 none, 2, 3, 4

void handleTouchFixed(int rawTouch) {
  bool isTouch = (rawTouch < touchThreshold);
  unsigned long now = millis();

  if (isTouch) {
    if (!currentlyTouched) {
      currentlyTouched = true;
      touchDownMs = now;

      tapCount++;
      lastTapEdgeMs = now;
      waitingToFinalize = true;

      Serial.printf("\n🚨 >>> TAP %d DETECTED <<< 🚨 (raw=%d, threshold=%d)\n", tapCount, rawTouch, touchThreshold);
    }

    // Long press
    if (currentlyTouched && (now - touchDownMs >= LONG_PRESS_MS)) {
      Serial.println("[TOUCH] Long Press Detected (5s)! Stopping SOS...");
      stopAwsSos();

      // reset tap state
      currentlyTouched = false;
      tapCount = 0;
      waitingToFinalize = false;
      pendingTapAction = 0;

      delay(300); // Debounce
      return;
    }
  } else {
    if (currentlyTouched) {
      currentlyTouched = false;
      Serial.printf(">>> Tap Released <<< (held %lu ms)\n", now - touchDownMs);
      lastTapEdgeMs = now; // update edge time on release too
    }
  }

  // FINALIZE after user stops tapping for TAP_IDLE_MS
  if (waitingToFinalize && !currentlyTouched && (now - lastTapEdgeMs >= TAP_IDLE_MS)) {
    waitingToFinalize = false;

    Serial.printf("[TOUCH] Finalizing: %d taps detected\n", tapCount);

    if (tapCount == 2) pendingTapAction = 2;
    else if (tapCount == 3) pendingTapAction = 3;
    else if (tapCount >= 4) pendingTapAction = 4;

    Serial.printf("[TOUCH] Pending action set to: %d\n", pendingTapAction);
    tapCount = 0;
  }
}

// ============================================================================
// ✅ SAME LOGIC AS YOUR PREVIOUS CODE (but guaranteed to run)
// 3 taps -> Activity DISABLED
// 4 taps -> Activity ENABLED
// ============================================================================
void processPendingTapAction() {
  if (pendingTapAction == 0) return;

  int action = pendingTapAction;
  pendingTapAction = 0;
  Serial.printf("\n[ACTION] Processing tap action: %d\n", action);

  if (action == 2) {
    Serial.println("[TOUCH] Double Tap Detected! Triggering SOS...");
    if (millis() - lastSosTrigger >= SOS_COOLDOWN) {
      lastSosTrigger = millis();
      triggerAwsSos();
    } else {
      Serial.println("[AWS] SOS request cooling down...");
    }
  }
  else if (action == 3) {
    Serial.println("[TOUCH] Triple Tap Detected! Disabling Activity Mode...");
    activityMode = false;
    activityDurationSeconds = 0;
    activityEndTime = 0;

    Serial.println("[ACTIVITY] Sending ACTIVITY:DISABLED via UDP...");
    sendBleNotification("ACTIVITY:DISABLED");
    Serial.println("[ACTIVITY] ACTIVITY:DISABLED sent!");
    vibratePulse(3, 200, 200);
  }
  else if (action == 4) {
    Serial.println("[TOUCH] Four Taps Detected! Enabling Activity Mode...");

    activityMode = true;

    if (activityDurationSeconds > 0) {
      activityEndTime = millis() + (activityDurationSeconds * 1000UL);
      Serial.printf("[ACTIVITY] Timer set for %d seconds\n", activityDurationSeconds);
    } else {
      activityEndTime = 0;
      Serial.println("[ACTIVITY] No timer — indefinite mode");
    }

    Serial.println("[ACTIVITY] Sending ACTIVITY:ENABLED via UDP...");
    sendBleNotification("ACTIVITY:ENABLED");
    Serial.println("[ACTIVITY] ACTIVITY:ENABLED sent!");
    vibratePulse(4, 200, 200);
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);

  Serial.println("\n\n========================================");
  Serial.println("  BACKUP ESP SOS — INITIALIZING");
  Serial.println("========================================");

  pinMode(VIBRATION_PIN, OUTPUT);
  digitalWrite(VIBRATION_PIN, LOW);

  // I2C init (same as your pulse code)
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000);

  // ------------------- MAX30102 INIT (UNCHANGED LOGIC) -------------------
  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found! Check wiring...");
    while (1) delay(10);
  }

  // Good HR settings (UNCHANGED)
  sensor.setup(
    0xFF,  // LED brightness
    8,     // sample average
    2,     // Red + IR
    200,   // sample rate
    411,   // pulse width
    16384  // ADC range
  );

  sensor.setPulseAmplitudeIR(0xFF);
  sensor.setPulseAmplitudeRed(0x4F);
  sensor.setPulseAmplitudeGreen(0);

  // ------------------- MPU6050 INIT -------------------
  // Wake up MPU6050
  if (!mpuWriteByte(MPU_PWR_MGMT_1, 0x00)) {
    Serial.println("MPU6050 not found / init failed. Check wiring.");
    while (1) delay(10);
  }

  Serial.println("Started: MAX30102 (BPM) + MPU6050 (Motion)");
  Serial.println("Format: BPM=<value>  MOTION=<value>  ACC=(x,y,z)  GYRO=(x,y,z)");

  // --- Touch Plate Initialization ---
  // Taking a quick test read just to see on console
  Serial.printf("[TOUCH] Initial reading: %d. Threshold is: %d\n", touchRead(TOUCH_PIN), touchThreshold);

  // Seed random generator for AWS UUIDs
  randomSeed(analogRead(0));

  // --- WiFi Connection ---
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

    // CRITICAL: Re-initialize and wake up the touch peripheral AFTER WiFi connects
    delay(500);
    touchAttachInterrupt(TOUCH_PIN, [](){}, touchThreshold);
    Serial.println("[TOUCH] Peripheral re-initialized after WiFi start.");

    // Start UDP Listener
    udp.begin(UDP_PORT);
    Serial.printf("[UDP] Listening for GPS Data on port %d\n", UDP_PORT);
  } else {
    Serial.println("[WiFi] WARNING: Failed to connect to GPS ESP.");
  }

  // --- BLE Server Init ---
  Serial.println("[BLE] Initializing BLE Server...");
  BLEDevice::init("Suraksha_SOS");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new SosServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pTxCharacteristic->addDescriptor(new BLE2902());

  pRxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE
  );
  pRxCharacteristic->setCallbacks(new SosRxCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
  Serial.println("[BLE] Advertising as 'Suraksha_SOS'");

  Serial.println("========================================");
  Serial.println("  SYSTEM READY");
  Serial.println("  BLE: Suraksha_SOS");
  Serial.printf("  WiFi: %s\n", WiFi.status() == WL_CONNECTED ? "Connected" : "Not connected");
  Serial.println("========================================");
}

void loop() {

  // --- BLE re-advertising if phone disconnects ---
  if (!bleDeviceConnected && bleOldDeviceConnected) {
    delay(100);
    pServer->startAdvertising();
    Serial.println("[BLE] Re-advertising...");
    bleOldDeviceConnected = bleDeviceConnected;
  }
  if (bleDeviceConnected && !bleOldDeviceConnected) {
    bleOldDeviceConnected = bleDeviceConnected;
  }

  if (activityMode && activityEndTime > 0 && millis() >= activityEndTime)
  {
    activityMode = false;
    activityDurationSeconds = 0;
    Serial.println("[ACTIVITY] Expired — pulse monitoring resumed");
  }

  // --- 1-SECOND PERIODIC PRINTS (GPS & TOUCH) ---
  static unsigned long lastDebugPrint = 0;

  int rawTouch = touchRead(TOUCH_PIN); // Read it globally for the loop

  // ✅ MULTI-TAP FIX handler
  handleTouchFixed(rawTouch);

  // ✅ Ensure actions fire even if finalized here
  processPendingTapAction();

  if (millis() - lastDebugPrint >= 1000) {
    lastDebugPrint = millis();

    Serial.println("========================================");
    Serial.printf("RAW TOUCH VALUE: %d\n", rawTouch);
    if (currentlyTouched) {
      Serial.println("TOUCH ACTIVE: 🖐️ YES");
    } else {
      Serial.println("TOUCH ACTIVE: NO");
    }

    Serial.print("GPS=[");
    Serial.print(latestGpsData);
    Serial.println("]");
    Serial.println("========================================");
  }

  // --- 2. CHECK FOR INCOMING UDP GPS ---
  if (WiFi.status() == WL_CONNECTED) {
    int packetSize = udp.parsePacket();
    if (packetSize > 0) {
      int len = udp.read(udpBuffer, sizeof(udpBuffer) - 1);
      if (len > 0) {
        udpBuffer[len] = '\0';
        String data = String(udpBuffer);
        data.trim(); // Remove any stray newlines or spaces
        latestGpsData = data; // Store it globally for the unified print

        if (data.startsWith("LAT:")) {
          int commaIndex = data.indexOf(",");
          if (commaIndex != -1) {
            latestLat = data.substring(4, commaIndex);
            int lonIndex = data.indexOf("LON:");
            if (lonIndex != -1) {
              latestLon = data.substring(lonIndex + 4);
            }
          }
        }
        // --- ADDED: ACTIVITY MODE PARSING OVER UDP ---
        else if (data.startsWith("ACTIVITY:1")) {
          int commaIndex = data.indexOf(",");
          if (commaIndex != -1) {
            String secString = data.substring(commaIndex + 9); // After "SECONDS:"
            activityDurationSeconds = secString.toInt();
            activityMode = true;
            activityEndTime = millis() + (activityDurationSeconds * 1000);
            Serial.printf("[ACTIVITY] Enabled for %d seconds\n", activityDurationSeconds);
          }
        }
        else if (data.startsWith("ACTIVITY:0")) {
          activityMode = false;
          activityDurationSeconds = 0;
          activityEndTime = 0;
          Serial.println("[ACTIVITY] Disabled");
        }
      }
    }
  }

  // ------------------- MOTION (READ ~50Hz) -------------------
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

  // =======================
  // ✅ PULSE SENSOR LOOP
  // =======================
  sensor.check();

  // Drain the FIFO fully every loop
  unsigned long loopCounter = 0;
  while (sensor.available()) {
    loopCounter++;

    // Check touch every 10 samples to prevent starving it during fast HR reads
    if (loopCounter % 10 == 0) {
      int innerTouch = touchRead(TOUCH_PIN);
      handleTouchFixed(innerTouch);
      processPendingTapAction(); // ✅ ensures 3/4 tap actions trigger even inside FIFO loop
    }

    long ir = sensor.getIR();
    sensor.nextSample();

    // If finger not present, reset and don't print anything
    if (ir < 20000) {   // your IR is ~200k with finger, so 20000 is safe
      count = 0;
      idx = 0;
      continue;
    }

    if (checkForBeat(ir)) {
      unsigned long now = millis();
      unsigned long dt = now - lastBeat;
      lastBeat = now;

      // reject unreal timings
      if (dt > 250 && dt < 2000) { // 30..240 BPM range
        bpm = 60.0f / (dt / 1000.0f);

        if (bpm >= 35 && bpm <= 200) {
          buf[idx] = bpm;
          idx = (idx + 1) % N;
          if (count < N) count++;

          // ✅ Print Heartbeat and Motion ONLY when detected
          Serial.println("----------------------------------------");
          Serial.print("BPM=");
          Serial.println(avgBpm(), 1);

          Serial.print("MOTION=");
          Serial.print(motionScore, 3);
          Serial.printf(" ACTIVITY=%d\n", activityMode);
          Serial.println("----------------------------------------");

          // =======================
          // AUTO SOS LOGIC
          // =======================
          if (!sosActive && !activityMode && (millis() - lastAutoSosTime >= AUTO_SOS_COOLDOWN)) {
            float currentBpm = avgBpm();
            // Trigger auto-SOS if heartbeat is dangerously low (<40) or dangerously high (>140)
            if (currentBpm > 0 && (currentBpm < 40 || currentBpm > 140)) {
              Serial.printf("\n🚨 [AUTO-SOS] Abnormal HR detected: %.1f BPM! Triggering SOS.\n", currentBpm);
              lastAutoSosTime = millis();
              triggerAwsSos();
              sosActive = true; // Optional: prevents endless looping without reset
            }
          }
        }
      }
    }
  }
}