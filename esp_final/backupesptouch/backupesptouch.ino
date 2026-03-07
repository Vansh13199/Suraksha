// ============================================================================
// BACKUP ESP GPS FIRMWARE (backupesptouch.ino)
// ============================================================================
// This ESP32 acts as a simple GPS relay:
// 1. BLE Server: Receives GPS (LAT:xx,LON:yy) from the Flutter mobile app.
// 2. WiFi AP: Creates a hotspot ("ESP-GPS") for the SOS ESP to connect to.
// 3. UDP Broadcast: Broadcasts the received GPS data to the AP network so the 
//    SOS ESP can receive it on port 4210 without a direct BLE connection.
// ============================================================================

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <WiFiUdp.h>

#define LED_PIN 2  // Built-in LED



// ============================================================================
// WiFi STA CONFIG (Connect to phone hotspot for internet)
// ============================================================================
const char* sta_ssid     = "Nothing";
const char* sta_password = "12345678";
bool staConnected = false;
unsigned long lastStaAttempt = 0;
#define STA_RETRY_INTERVAL 30000  // Retry STA every 30s

// ============================================================================
// GPS DATA CACHE
// ============================================================================
float storedLat = 0.0;
float storedLon = 0.0;
bool gpsDataAvailable = false;
unsigned long lastGpsReceiveTime = 0;

// ============================================================================
// BLE CONFIG
// ============================================================================
BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic = NULL;
BLECharacteristic* pRxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// UUIDs matching the Flutter App
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// ============================================================================
// UDP BROADCAST (To send GPS to SOS ESP)
// ============================================================================
#define UDP_BROADCAST_PORT 4210
WiFiUDP udpGps;
unsigned long lastGpsBroadcast = 0;
#define GPS_BROADCAST_INTERVAL 5000  // Broadcast every 5s

// ============================================================================
// BLE CALLBACKS
// ============================================================================
class GpsServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("[BLE] Phone connected — waiting for GPS...");
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
      if (rxValue.startsWith("LAT:")) {
        int commaIdx = rxValue.indexOf(',');
        if (commaIdx > 0 && rxValue.indexOf("LON:") > 0) {
          storedLat = rxValue.substring(4, commaIdx).toFloat();
          storedLon = rxValue.substring(commaIdx + 5).toFloat();
          gpsDataAvailable = true;
          lastGpsReceiveTime = millis();
          Serial.printf("[GPS] Updated from phone: %.6f, %.6f\n", storedLat, storedLon);
        }
      }
      // --- ADDED: Forwarding ACTIVITY mode safely to SOS ESP over UDP ---
      else if (rxValue.startsWith("ACTIVITY:")) {
        IPAddress broadcastIp = ~WiFi.subnetMask() | WiFi.localIP();
        udpGps.beginPacket(broadcastIp, UDP_BROADCAST_PORT);
        udpGps.print(rxValue);
        udpGps.endPacket();
        Serial.println("[UDP] Forwarded ACTIVITY Mode command to SOS ESP");
      }
    }
  }
};

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

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // --- 1. WiFi STA ---
  WiFi.mode(WIFI_STA);

  // Connect STA to phone hotspot
  connectToInternet();

  // --- 2. BLE ---
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

  // --- 3. Start Listening for incoming UDP from SOS ESP ---
  udpGps.begin(UDP_BROADCAST_PORT);
  
  Serial.println("========================================");
  Serial.println("  BACKUP ESP GPS — READY");
  Serial.println("  WiFi STA    : " + String(staConnected ? "Connected" : "No Internet"));
  Serial.println("  BLE Name    : Suraksha_GPS");
  Serial.printf("  UDP Listener: Port %d\n", UDP_BROADCAST_PORT);
  Serial.println("========================================");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  // --- 1. Broadcast GPS to SOS ESP via UDP ---
  // Sends data like "LAT:28.6139,LON:77.2090" to 192.168.4.255:4210
  if (gpsDataAvailable && (millis() - lastGpsBroadcast >= GPS_BROADCAST_INTERVAL)) {
    lastGpsBroadcast = millis();
    String gpsData = "LAT:" + String(storedLat, 6) + ",LON:" + String(storedLon, 6);

    // Broadcast globally to the subnet instead of 255.255.255.255 to traverse Android Hotspots
    IPAddress broadcastIp = ~WiFi.subnetMask() | WiFi.localIP();

    udpGps.beginPacket(broadcastIp, UDP_BROADCAST_PORT);
    udpGps.print(gpsData);
    udpGps.endPacket();

    // Blink LED to indicate GPS was sent
    digitalWrite(LED_PIN, HIGH);
    delay(50);
    digitalWrite(LED_PIN, LOW);

    Serial.print("[UDP] GPS Broadcast to ");
    Serial.print(broadcastIp);
    Serial.print(": ");
    Serial.println(gpsData);
  }

  // --- 2. BLE re-advertising if disconnected ---
  if (!deviceConnected && oldDeviceConnected) {
    delay(100);
    pServer->startAdvertising();
    Serial.println("[BLE] Re-advertising...");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  // --- 3. WiFi STA reconnect handling ---
  if (WiFi.status() != WL_CONNECTED) {
    staConnected = false;
    if (millis() - lastStaAttempt >= STA_RETRY_INTERVAL) {
      lastStaAttempt = millis();
      connectToInternet();
    }
  } else {
    staConnected = true;
  }

  // Request GPS periodically from the phone if connected (optional fallback)
  static unsigned long lastGpsRequest = 0;
  if (deviceConnected && (millis() - lastGpsRequest >= 10000)) {
    lastGpsRequest = millis();
    if (pTxCharacteristic != NULL) {
      pTxCharacteristic->setValue("REQ:GPS");
      pTxCharacteristic->notify();
    }
  }

  // --- 4. Listen for incoming UDP (from SOS ESP) and forward to BLE ---
  int packetSize = udpGps.parsePacket();
  if (packetSize) {
    char incomingPacket[255];
    int len = udpGps.read(incomingPacket, 255);
    if (len > 0) {
      incomingPacket[len] = '\0';
      String receivedCmd = String(incomingPacket);
      receivedCmd.trim();

      // We ignore our own GPS broadcasts ("LAT:")
      if (!receivedCmd.startsWith("LAT:")) {
        Serial.printf("[UDP REC] Received from SOS ESP: %s\n", receivedCmd.c_str());

        // Forward to phone via BLE if connected
        if (deviceConnected && pTxCharacteristic != NULL) {
          pTxCharacteristic->setValue(receivedCmd.c_str());
          pTxCharacteristic->notify();
          Serial.println("[BLE] Forwarded UDP command to phone!");
        }
      }
    }
  }

  delay(10);
}
