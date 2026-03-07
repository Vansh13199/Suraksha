#include <WiFi.h>
#include <WiFiUdp.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// --- Config for "SOS ESP" (Now in Main File) ---
// 1. Acts as AP for the other ESP32
// 2. Connects to Router for Internet
// 3. BLE Server "Suraksha_SOS" for App SOS triggers

const char* ap_ssid = "Suraksha_ESP32_AP";
const char* ap_password = "Suraksha@admin";

const char* home_wifi_ssid = "Vansh96-Extended";
const char* home_wifi_password = "vansh422";

// BLE UUIDs
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" 
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

WiFiUDP udp;
const int udpPort = 4210;
char packetBuffer[255]; 

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("BLE Device Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("BLE Device Disconnected");
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();
      if (rxValue.length() > 0) {
        Serial.print("Received Value: ");
        Serial.println(rxValue);

        // Handle SOS Trigger from App
        if (rxValue.startsWith("SOS:")) {
           Serial.println("!!! SOS TRIGGERED !!!");
           
           // Parse GPS if present (Format: SOS:LAT:12.34,LON:56.78)
           int latIndex = rxValue.indexOf("LAT:");
           int lonIndex = rxValue.indexOf("LON:");
           
           if (latIndex != -1 && lonIndex != -1) {
             String lat = rxValue.substring(latIndex + 4, lonIndex - 1); // -1 for comma
             String lon = rxValue.substring(lonIndex + 4);
             
             Serial.println("--------------------------------");
             Serial.println("   RECEIVED APP GPS COORDINATES   ");
             Serial.print("   LAT: "); Serial.println(lat);
             Serial.print("   LON: "); Serial.println(lon);
             Serial.println("--------------------------------");
           }
        }
      }
    }
};

void setup() {
  Serial.begin(115200);

  // 1. WiFi Setup (AP + Station)
  WiFi.mode(WIFI_AP_STA);
  
  // Create AP
  Serial.print("Creating AP: "); Serial.println(ap_ssid);
  WiFi.softAP(ap_ssid, ap_password);
  Serial.print("AP IP: "); Serial.println(WiFi.softAPIP());

  // Connect to Home WiFi
  Serial.print("Connecting to Home WiFi: "); Serial.println(home_wifi_ssid);
  WiFi.begin(home_wifi_ssid, home_wifi_password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println("");
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Connected to Home WiFi! IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("Failed to connect to Home WiFi.");
  }

  // 2. UDP Setup
  udp.begin(udpPort);
  Serial.printf("UDP Listening on port %d\n", udpPort);

  // 3. BLE Setup
  BLEDevice::init("Suraksha_SOS"); // Distinct Name
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  pTxCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID_TX,
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pTxCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic * pRxCharacteristic = pService->createCharacteristic(
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
  Serial.println("BLE Service Started. Waiting for client...");
}

void loop() {
  // UDP Handling (receiving from GPS ESP)
  int packetSize = udp.parsePacket();
  if (packetSize) {
    int len = udp.read(packetBuffer, 255);
    if (len > 0) packetBuffer[len] = 0;
    
    Serial.print("UDP Rx: ");
    Serial.println(packetBuffer);
    
    // Optionally relay this GPS data via BLE to the SOS App
    if (deviceConnected) {
       pTxCharacteristic->setValue((uint8_t*)packetBuffer, len);
       pTxCharacteristic->notify();
    }
  }

  // BLE Re-advertising logic
  if (!deviceConnected && oldDeviceConnected) {
      delay(500);
      pServer->startAdvertising();
      Serial.println("Restarting advertising...");
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }
  delay(10);
}
