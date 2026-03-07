/*
 * ESP32 Touch Sensor Calibration Tool for Material Differentiation
 * 
 * Purpose: Determine the specific capacitance range for Aluminum Foil vs Copper Sheet.
 * 
 * Instructions:
 * 1. Upload this sketch to your ESP32.
 * 2. Open Serial Plotter (Tools > Serial Plotter) at 115200 baud.
 * 3. Step 1: Do NOT touch the sensor at all for 5 seconds. (Baseline)
 * 4. Step 2: Touch with ALUMINUM FOIL for 5 seconds. Note the MIN and MAX values.
 * 5. Step 3: Touch with COPPER SHEET for 5 seconds. Note the MIN and MAX values.
 * 6. Step 4: Touch with FINGER directly for 5 seconds. Note the MIN and MAX values.
 * 
 * Result:
 * You are looking for a unique range for Aluminum.
 * Example:
 * - Untouched: 70-75
 * - Aluminum: 25-35
 * - Copper: 10-15 (or 40-50 depending on setup)
 * - Finger: 10-20
 * 
 * If Aluminum range (e.g., 25-35) does not overlap with Copper/Finger, we can differentiate!
 * Use these values to set ALUMINUM_MIN and ALUMINUM_MAX in the main sketch.
 */

const int touchPin = 4; // GPIO 4 (T0)

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Starting Calibration...");
  Serial.println("Open Serial Plotter for best visualization!");
}

void loop() {
  int value = touchRead(touchPin);
  
  // Format for Serial Plotter: "Label:Value"
  Serial.print("Raw_Value:");
  Serial.println(value);
  
  delay(50); // Fast sampling for smooth plotting
}
