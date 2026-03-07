// ✅ ESP32 + MAX30102 (Pulse) + MPU6050 (Motion) integrated
// ❗Pulse sensor code is kept EXACTLY same (only motion code added around it)
// I2C: SDA=18, SCL=19
// MPU6050 address: 0x68 (default). If your MPU is 0x69, change MPU_ADDR to 0x69.

#include <Arduino.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

// ---------------- PINS ----------------
#define SDA_PIN 18
#define SCL_PIN 19

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

void setup() {
  Serial.begin(115200);
  delay(300);

  // I2C init (same as your pulse code)
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000);

  // ------------------- MAX30102 INIT (UNCHANGED LOGIC) -------------------
  if (!sensor.begin(Wire, I2C_SPEED_FAST)) {
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
}

void loop() {
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
  // ✅ PULSE SENSOR LOOP (UNCHANGED)
  // =======================
  sensor.check();

  while (sensor.available()) {
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

          // ✅ Print pulse + motion together (pulse logic unchanged, only print extended)
          Serial.print("BPM=");
          Serial.print(avgBpm(), 1);
          Serial.print("  MOTION=");
          Serial.print(motionScore, 3);

          Serial.print("  ACC=(");
          Serial.print(ax_g, 2); Serial.print(",");
          Serial.print(ay_g, 2); Serial.print(",");
          Serial.print(az_g, 2); Serial.print(")");

          Serial.print("  GYRO=(");
          Serial.print(gx_dps, 1); Serial.print(",");
          Serial.print(gy_dps, 1); Serial.print(",");
          Serial.print(gz_dps, 1); Serial.print(")");

          Serial.println();
        }
      }
    }
  }
}