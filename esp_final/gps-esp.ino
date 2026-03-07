// ============================================================================
// ✅ SURAKSHA+ GPS ESP — FINAL FIRMWARE
// ============================================================================
// This ESP32 acts as the GPS & Internet bridge for ESP SOS:
//
// 1. WiFi AP+STA (AP for ESP SOS, STA for internet via phone hotspot/router)
// 2. BLE Server (receives GPS from Flutter app's Debug Screen)
// 3. HTTP Server (serves GPS to ESP SOS at /gps)
// 4. Internet Passthrough (ESP SOS → GPS ESP WiFi → Internet → Amplify)
//
// GPS Source: Flutter App → BLE → GPS ESP → BLE broadcast → ESP SOS
// The app sends "LAT:xx.xxxx,LON:yy.yyyy" via BLE (auto-send every 10s)
// GPS ESP broadcasts GPS to ESP SOS via a second BLE characteristic
// ============================================================================

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <WebServer.h>

// ============================================================================
// WiFi CONFIG
// ============================================================================
// AP — ESP SOS connects to this
const char* ap_ssid     = "ESP-GPS";
const char* ap_password = "Suraksha@admin";

// STA — Connect to internet source (phone hotspot or home WiFi)
const char* sta_ssid     = "realme 12 Pro + 5G";
const char* sta_password = "........";

bool staConnected = false;
unsigned long lastStaAttempt = 0;
#define STA_RETRY_INTERVAL 30000  // Retry STA every 30s

// ============================================================================
// HTTP SERVER
// ============================================================================
WebServer server(80);

// ============================================================================
// GPS DATA (received from Flutter app via BLE)
// ============================================================================
float storedLat = 0.0;
float storedLon = 0.0;
bool gpsDataAvailable = false;
unsigned long lastGpsReceiveTime = 0;

// GPS request interval — ask phone for GPS periodically
unsigned long lastGpsRequest = 0;
#define GPS_REQUEST_INTERVAL 10000  // Request GPS from phone every 10s

// ============================================================================
// BLE CONFIG
// ============================================================================
BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic = NULL;
BLECharacteristic* pRxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// UDP GPS Broadcast to ESP SOS
#define UDP_BROADCAST_PORT 4210
WiFiUDP udpGps;
unsigned long lastGpsBroadcast = 0;
#define GPS_BROADCAST_INTERVAL 5000  // Broadcast GPS to ESP SOS every 5s

// ============================================================================
// STATUS LED (built-in)
// ============================================================================
#define LED_PIN 2
unsigned long lastLedToggle = 0;
bool ledState = false;

// ============================================================================
// FORWARD DECLARATIONS
// ============================================================================
void connectToInternet();
void requestGpsFromPhone();

// ============================================================================
// BLE CALLBACKS
// ============================================================================
class GpsServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("[BLE] Phone connected — will receive GPS data");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("[BLE] Phone disconnected");
  }
};

class GpsRxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue = pCharacteristic->getValue();

    if (rxValue.length() > 0) {
      Serial.print("[BLE] Received: "); Serial.println(rxValue);

      // Parse GPS Data from Flutter app
      // Format: LAT:xx.xxxx,LON:yy.yyyy
      String data = rxValue;
      if (data.startsWith("LAT:")) {
        int commaIdx = data.indexOf(',');
        if (commaIdx > 0 && data.indexOf("LON:") > 0) {
          storedLat = data.substring(4, commaIdx).toFloat();
          storedLon = data.substring(commaIdx + 5).toFloat();  // skip ",LON:"
          gpsDataAvailable = true;
          lastGpsReceiveTime = millis();
          Serial.printf("[GPS] Updated from phone: %.6f, %.6f\n", storedLat, storedLon);
        }
      }

      // Also handle SOS trigger from app (optional, forward to serial)
      if (data.startsWith("SOS:")) {
        Serial.println("[BLE] SOS command received from app: " + data);
      }
    }
  }
};

// ============================================================================
// REQUEST GPS FROM PHONE (via BLE Notify)
// ============================================================================
void requestGpsFromPhone() {
  if (deviceConnected && pTxCharacteristic != NULL) {
    pTxCharacteristic->setValue("REQ:GPS");
    pTxCharacteristic->notify();
    Serial.println("[BLE] Sent GPS request to phone");
  }
}

// ============================================================================
// HTTP HANDLERS
// ============================================================================
void handleGps() {
  if (gpsDataAvailable) {
    String response = "LAT:" + String(storedLat, 6) + ",LON:" + String(storedLon, 6);
    server.send(200, "text/plain", response);
    Serial.print("[HTTP] Served GPS: "); Serial.println(response);
  } else {
    server.send(404, "text/plain", "NO_GPS_DATA");
    Serial.println("[HTTP] GPS requested — no data available yet");
  }
}

void handleRoot() {
  unsigned long uptime = millis() / 1000;
  int hours = uptime / 3600;
  int mins = (uptime % 3600) / 60;
  int secs = uptime % 60;

  String html = "<!DOCTYPE html><html><head><title>Suraksha+ GPS ESP</title>";
  html += "<meta http-equiv='refresh' content='5'>";
  html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<style>";
  html += "body{font-family:'Courier New',monospace;background:#0f0f23;color:#00ff41;padding:20px;margin:0;}";
  html += "h1{color:#ff6b6b;border-bottom:2px solid #ff6b6b;padding-bottom:10px;}";
  html += ".card{background:#1a1a3e;border:1px solid #333;border-radius:8px;padding:15px;margin:10px 0;}";
  html += ".label{color:#888;font-size:12px;text-transform:uppercase;}";
  html += ".value{color:#00ff41;font-size:18px;font-weight:bold;}";
  html += ".ok{color:#00ff41;} .warn{color:#ffaa00;} .err{color:#ff4444;}";
  html += ".grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;}";
  html += "</style></head><body>";

  html += "<h1>🛰️ SURAKSHA+ GPS ESP</h1>";

  // Internet
  html += "<div class='card'>";
  html += "<div class='label'>Internet Connection (STA)</div>";
  if (staConnected) {
    html += "<div class='value ok'>✅ Connected to: " + String(sta_ssid) + "</div>";
    html += "<div>IP: " + WiFi.localIP().toString() + "</div>";
  } else {
    html += "<div class='value err'>❌ Not Connected</div>";
    html += "<div class='warn'>⚠️ ESP SOS cannot reach Amplify</div>";
  }
  html += "</div>";

  // GPS
  html += "<div class='card'>";
  html += "<div class='label'>GPS Data (from Flutter App via BLE)</div>";
  if (gpsDataAvailable) {
    html += "<div class='value ok'>📍 " + String(storedLat, 6) + ", " + String(storedLon, 6) + "</div>";
    html += "<div>Last update: " + String((millis() - lastGpsReceiveTime) / 1000) + "s ago</div>";
  } else {
    html += "<div class='value warn'>⏳ Waiting for GPS from phone...</div>";
    html += "<div>Open Debug Screen in app → Enable Auto Send</div>";
  }
  html += "</div>";

  // Connections
  html += "<div class='grid'>";
  html += "<div class='card'><div class='label'>Phone BLE</div><div class='value " + String(deviceConnected ? "ok'>✅ Connected" : "warn'>📡 Advertising") + "</div></div>";
  html += "<div class='card'><div class='label'>ESP SOS (AP Clients)</div><div class='value'>" + String(WiFi.softAPgetStationNum()) + " connected</div></div>";
  html += "</div>";

  // Uptime
  html += "<div class='card'><div class='label'>Uptime</div><div class='value'>";
  html += String(hours) + "h " + String(mins) + "m " + String(secs) + "s";
  html += "</div></div>";

  html += "</body></html>";
  server.send(200, "text/html", html);
}

void handleStatus() {
  String json = "{";
  json += "\"gpsAvailable\":" + String(gpsDataAvailable ? "true" : "false") + ",";
  json += "\"lat\":" + String(storedLat, 6) + ",";
  json += "\"lon\":" + String(storedLon, 6) + ",";
  json += "\"gpsAgeSec\":" + String(gpsDataAvailable ? (millis() - lastGpsReceiveTime) / 1000 : 0) + ",";
  json += "\"bleConnected\":" + String(deviceConnected ? "true" : "false") + ",";
  json += "\"staConnected\":" + String(staConnected ? "true" : "false") + ",";
  json += "\"apClients\":" + String(WiFi.softAPgetStationNum()) + ",";
  json += "\"uptimeMs\":" + String(millis());
  json += "}";
  server.send(200, "application/json", json);
}

// ============================================================================
// WiFi — CONNECT TO INTERNET (STA)
// ============================================================================
void connectToInternet() {
  Serial.print("[WiFi] Connecting to: "); Serial.println(sta_ssid);
  WiFi.begin(sta_ssid, sta_password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(250);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    staConnected = true;
    Serial.print("[WiFi] STA Connected! IP: "); Serial.println(WiFi.localIP());
    Serial.println("[WiFi] Internet passthrough ready for ESP SOS");
  } else {
    staConnected = false;
    Serial.println("[WiFi] STA connection failed");
  }
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(300);

  // --- LED ---
  pinMode(LED_PIN, OUTPUT);

  // --- WiFi AP+STA ---
  WiFi.mode(WIFI_AP_STA);

  // Start AP
  WiFi.softAP(ap_ssid, ap_password);
  Serial.print("[WiFi] AP started: "); Serial.println(ap_ssid);
  Serial.print("[WiFi] AP IP: "); Serial.println(WiFi.softAPIP());

  // Connect to internet
  connectToInternet();

  // --- HTTP Server ---
  server.on("/", handleRoot);
  server.on("/gps", handleGps);
  server.on("/status", handleStatus);
  server.begin();
  Serial.println("[HTTP] Server started on port 80");

  // --- BLE ---
  BLEDevice::init("Suraksha_GPS");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new GpsServerCallbacks());

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
  pRxCharacteristic->setCallbacks(new GpsRxCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("========================================");
  Serial.println("  SURAKSHA+ GPS ESP — READY");
  Serial.println("  WiFi AP : " + String(ap_ssid));
  Serial.println("  WiFi STA: " + String(staConnected ? "Connected" : "No Internet"));
  Serial.println("  BLE     : Suraksha_GPS (phone GPS)");
  Serial.println("  UDP     : GPS broadcast on port 4210");
  Serial.println("  HTTP    : /gps  /status  /");
  Serial.println("========================================");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  // --- 1. Handle HTTP requests ---
  server.handleClient();

  // --- 2. Broadcast GPS to ESP SOS via UDP ---
  if (gpsDataAvailable && (millis() - lastGpsBroadcast >= GPS_BROADCAST_INTERVAL)) {
    lastGpsBroadcast = millis();
    String gpsData = "LAT:" + String(storedLat, 6) + ",LON:" + String(storedLon, 6);

    // UDP broadcast to 192.168.4.255 (all AP clients)
    udpGps.beginPacket(IPAddress(192, 168, 4, 255), UDP_BROADCAST_PORT);
    udpGps.print(gpsData);
    udpGps.endPacket();
    Serial.print("[UDP] GPS broadcast: "); Serial.println(gpsData);
  }

  // --- 3. Request GPS from phone periodically ---
  if (deviceConnected && (millis() - lastGpsRequest >= GPS_REQUEST_INTERVAL)) {
    lastGpsRequest = millis();
    requestGpsFromPhone();
  }

  // --- 3. WiFi STA reconnect ---
  if (WiFi.status() != WL_CONNECTED) {
    staConnected = false;
    if (millis() - lastStaAttempt >= STA_RETRY_INTERVAL) {
      lastStaAttempt = millis();
      connectToInternet();
    }
  } else {
    staConnected = true;
  }

  // --- 4. BLE re-advertising ---
  if (!deviceConnected && oldDeviceConnected) {
    delay(100);
    pServer->startAdvertising();
    Serial.println("[BLE] Re-advertising");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  // --- 5. Status LED ---
  unsigned long blinkInterval;
  if (gpsDataAvailable && staConnected) {
    blinkInterval = 0;  // Solid ON = all good
    digitalWrite(LED_PIN, HIGH);
  } else if (gpsDataAvailable) {
    blinkInterval = 1000;  // Slow blink = GPS OK, no internet
  } else {
    blinkInterval = 200;   // Fast blink = no GPS
  }

  if (blinkInterval > 0 && (millis() - lastLedToggle >= blinkInterval)) {
    lastLedToggle = millis();
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState ? HIGH : LOW);
  }

  // --- 6. Periodic status log ---
  static unsigned long lastLog = 0;
  if (millis() - lastLog >= 10000) {
    lastLog = millis();
    Serial.printf("[STATUS] GPS=%s(%.6f,%.6f) STA=%s BLE=%s Clients=%d\n",
      gpsDataAvailable ? "OK" : "NO",
      storedLat, storedLon,
      staConnected ? "OK" : "NO",
      deviceConnected ? "OK" : "NO",
      WiFi.softAPgetStationNum());
  }

  delay(5);
}
