
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <WiFiUdp.h>

// --- Config for "GPS ESP" (Now in Secondary File) ---
// 1. Acts as Station (connects to SOS ESP)
// 2. BLE Server "Suraksha_GPS" for Debug Screen
// 3. Sends GPS data via UDP to SOS ESP

const char* ap_ssid = "Suraksha_ESP32_AP";
const char* ap_password = "Suraksha@admin";

WiFiUDP udp;
const int udpPort = 4210;
// We will send to the Gateway IP (which connects us to the AP)
// or we can fallback to broadcast if needed.

BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic = NULL;
BLECharacteristic* pRxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// UUIDs (Same service UUIDs are fine, or can be different)
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" 
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device Disconnected");
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();

      if (rxValue.length() > 0) {
        Serial.println("*********");
        Serial.print("Received Value: ");
        Serial.println(rxValue);
        Serial.println("*********");

        String data = rxValue;

        // Parse GPS Data
        // Expected Format: LAT:xx.xxxx,LON:yy.yyyy
        if (data.startsWith("LAT:")) {
             // 1. Send via UDP to SOS ESP
             if (WiFi.status() == WL_CONNECTED) {
                IPAddress targetIP = WiFi.gatewayIP(); // The AP is our gateway
                
                Serial.print("Sending UDP to "); Serial.println(targetIP);
                udp.beginPacket(targetIP, udpPort);
                udp.print(data); 
                udp.endPacket();
             } else {
               Serial.println("WiFi not connected, skipping UDP");
             }
        }
      }
    }
};

void setup() {
  Serial.begin(115200);

  // 1. WiFi Setup (Station only)
  WiFi.mode(WIFI_STA);
  Serial.print("Connecting to AP: "); Serial.println(ap_ssid);
  WiFi.begin(ap_ssid, ap_password);

  // Non-blocking connect attempt (or blocking for a short while)
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 10) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println("");
  if (WiFi.status() == WL_CONNECTED) {
     Serial.print("Connected! IP: "); Serial.println(WiFi.localIP());
  } else {
     Serial.println("WiFi Connection Failed (Continuing offline...)");
  }

  udp.begin(udpPort);

  // 2. BLE Setup
  BLEDevice::init("Suraksha_GPS"); // Distinct Name
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

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
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("Waiting for client (Debug App)...");
}

void loop() {
  // Logic to send data back to phone via BLE if needed
  if (deviceConnected) {
      // Periodic updates...
  }

  // Disconnecting
  if (!deviceConnected && oldDeviceConnected) {
      delay(500);
      pServer->startAdvertising();
      Serial.println("start advertising");
      oldDeviceConnected = deviceConnected;
  }
  // Connecting
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }
  
  delay(10);
}
