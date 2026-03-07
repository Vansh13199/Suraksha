filepath = r'c:\Users\vkisl\Downloads\flutter_projects\flutter_projects\Suraksha+\esp_final\backupespsos\backupespsos.ino'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    # 1. Add global lastSessionId after "bool sosActive = false;"
    if 'bool sosActive = false;' in line:
        new_lines.append(line)
        new_lines.append('String lastSessionId = "";\r\n')
        continue
    
    # 2. Save sessionId globally in triggerAwsSos (after "String sessionId = generateUUID();")
    if 'String sessionId = generateUUID();' in line:
        new_lines.append(line)
        new_lines.append('  lastSessionId = sessionId;\r\n')
        continue
    
    # 3. Replace stopAwsSos with full AppSync update
    if 'void stopAwsSos() {' in line:
        new_lines.append('void stopAwsSos() {\r\n')
        new_lines.append('  Serial.println("[AWS] Stopping SOS...");\r\n')
        new_lines.append('  vibrateContinuous(3000);\r\n')
        new_lines.append('  sendBleNotification("SOS:STOP");\r\n')
        new_lines.append('\r\n')
        new_lines.append('  // Update AppSync to set isActive=false\r\n')
        new_lines.append('  if (lastSessionId.length() > 0 && WiFi.status() == WL_CONNECTED) {\r\n')
        new_lines.append('    Serial.printf("[AWS] Deactivating session: %s\\n", lastSessionId.c_str());\r\n')
        new_lines.append('    BLEDevice::deinit(false);\r\n')
        new_lines.append('    delay(100);\r\n')
        new_lines.append('\r\n')
        new_lines.append('    WiFiClientSecure *client = new WiFiClientSecure;\r\n')
        new_lines.append('    if (client) {\r\n')
        new_lines.append('      client->setInsecure();\r\n')
        new_lines.append('      HTTPClient http;\r\n')
        new_lines.append('      http.begin(*client, appsyncUrl);\r\n')
        new_lines.append('      http.addHeader("Content-Type", "application/json");\r\n')
        new_lines.append('      http.addHeader("x-api-key", apiKey);\r\n')
        new_lines.append('\r\n')
        new_lines.append('      String payload = "{\\"query\\":\\"mutation UpdateSOSSession($input: UpdateSOSSessionInput!) { updateSOSSession(input: $input) { id isActive } }\\",\\"variables\\":{\\"input\\":{\\"id\\":\\"" + lastSessionId + "\\",\\"isActive\\":false}}}";\r\n')
        new_lines.append('      Serial.println("[AWS] Stop Payload: " + payload);\r\n')
        new_lines.append('      int code = http.POST(payload);\r\n')
        new_lines.append('      if (code > 0) {\r\n')
        new_lines.append('        Serial.printf("[AWS] Stop response HTTP %d: %s\\n", code, http.getString().c_str());\r\n')
        new_lines.append('      } else {\r\n')
        new_lines.append('        Serial.printf("[AWS] Stop error: %s\\n", http.errorToString(code).c_str());\r\n')
        new_lines.append('      }\r\n')
        new_lines.append('      http.end();\r\n')
        new_lines.append('      delete client;\r\n')
        new_lines.append('    }\r\n')
        new_lines.append('    lastSessionId = "";\r\n')
        new_lines.append('    reinitBLE();\r\n')
        new_lines.append('  } else {\r\n')
        new_lines.append('    Serial.println("[AWS] No active session to stop or WiFi disconnected");\r\n')
        new_lines.append('  }\r\n')
        # Skip the old function body (next 3 lines: Serial.println, vibrateContinuous, sendBleNotification, closing brace)
        j = i + 1
        while j < len(lines) and lines[j].strip() != '}':
            j += 1
        # skip the closing brace too  
        j += 1
        # Now skip those lines by setting i
        # We can't manipulate i in a for loop, so we'll use a flag
        new_lines.append('}\r\n')
        # Mark lines to skip
        for skip in range(i + 1, j + 1):
            lines[skip] = '<<<SKIP>>>\r\n'
        continue
    
    if '<<<SKIP>>>' in line:
        continue
    
    new_lines.append(line)

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Done! stopAwsSos now updates AppSync with isActive=false")
