/*
 * Standalone MAX30102 BPM Calculation
 * Optimized for ESP32
 * 
 * Pins used:
 * SDA: 18
 * SCL: 19
 */

#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

// Sensor configuration
MAX30105 sensor;
const int SDA_PIN = 18;
const int SCL_PIN = 19;

// BPM Calculation variables
const int AVG_SAMPLES = 8;
float bpmBuffer[AVG_SAMPLES];
int bufferIndex = 0;
int samplesCount = 0;
unsigned long lastBeatTime = 0;

float getAverageBpm() {
  if (samplesCount == 0) return 0;
  float sum = 0;
  for (int i = 0; i < samplesCount; i++) sum += bpmBuffer[i];
  return sum / samplesCount;
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- STANDALONE BPM TEST ---");

  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000);

  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found! Check connections.");
    while (1) delay(100);
  }

  // Configuration from production code
  sensor.setup(0xFF, 8, 2, 200, 411, 16384);
  sensor.setPulseAmplitudeIR(0xFF);
  sensor.setPulseAmplitudeRed(0x4F);

  Serial.println("Sensor Initialized. Place your finger on the sensor...");
}

void loop() {
  sensor.check();
  
  while (sensor.available()) {
    long irValue = sensor.getIR();
    sensor.nextSample();

    // Check if a finger is detected
    if (irValue < 20000) {
      Serial.println("[STATUS] No finger detected");
      samplesCount = 0;
      bufferIndex = 0;
      continue;
    }

    // Heart beat detection
    if (checkForBeat(irValue)) {
      unsigned long now = millis();
      unsigned long delta = now - lastBeatTime;
      lastBeatTime = now;

      // Calculate BPM if interval is realistic (30-200 BPM)
      if (delta > 300 && delta < 2000) {
        float currentBpm = 60.0 / (delta / 1000.0);
        
        // Add to averaging buffer
        bpmBuffer[bufferIndex] = currentBpm;
        bufferIndex = (bufferIndex + 1) % AVG_SAMPLES;
        if (samplesCount < AVG_SAMPLES) samplesCount++;

        Serial.printf("[PULSE] Current: %.1f | Average: %.1f\n", currentBpm, getAverageBpm());
      }
    }
  }
  
  delay(10);
}
