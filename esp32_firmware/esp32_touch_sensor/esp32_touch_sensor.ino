/*
 * ESP32 Aluminium Plate Touch Test
 * 
 * Connect aluminium plate to GPIO 4 (Touch0) via a wire.
 * LED (GPIO 2) turns ON when plate is touched.
 * 
 * Open Serial Monitor (115200) to see raw touch values.
 * Adjust TOUCH_THRESHOLD if needed:
 *   - Untouched: typically 60-80
 *   - Touched:   typically 10-40
 *   - Lower threshold = less sensitive
 */

#define TOUCH_PIN       4   // GPIO 4 = Touch0 (aluminium plate)
#define LED_PIN         2   // Built-in LED
#define TOUCH_THRESHOLD 40  // Below this = touched (adjust after testing)

void setup() {
  Serial.begin(115200);
  delay(500);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  Serial.println("ESP32 Aluminium Plate Touch Test");
  Serial.println("Touch the plate and watch the values!");
  Serial.println("----------------------------------");
}

void loop() {
  int val = touchRead(TOUCH_PIN);
  bool touched = (val < TOUCH_THRESHOLD);

  // LED ON when touched
  digitalWrite(LED_PIN, touched ? HIGH : LOW);

  // Serial output
  Serial.printf("Touch: %d  |  %s\n", val, touched ? ">>> TOUCHED <<<" : "not touched");

  delay(100);
}
