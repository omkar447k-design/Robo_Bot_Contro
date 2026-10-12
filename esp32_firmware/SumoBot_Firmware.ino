/*
 * =====================================================================
 * SumoBot / Soccer Robot ESP32 Firmware with Dual Wireless OTA Update
 * =====================================================================
 * 
 * NETWORK:
 * - WiFi SoftAP: "SumoBot" (Pass: "12345678")
 * - Robot IP: 192.168.4.1
 * - UDP Port: 4210
 * 
 * WIRELESS OVER-THE-AIR (OTA) FLASHING (NO USB CABLE NEEDED):
 * 1. Arduino IDE OTA: Connect your PC to "SumoBot" WiFi. In Arduino IDE,
 *    go to Tools -> Port -> Network ports -> "SumoBot at 192.168.4.1" and click Upload!
 * 2. Web Browser OTA: Connect your Phone or PC to "SumoBot" WiFi, open
 *    http://192.168.4.1/update in any browser, choose "firmware.bin" and click Update!
 *
 * SAFETY FAILSAFE:
 * - Automatically stops all motors if no valid packet arrives for 200 ms.
 * =====================================================================
 */

#include <WiFi.h>
#include <WiFiUdp.h>
#include <ArduinoOTA.h>
#include <WebServer.h>
#include <Update.h>

// ================= PIN CONFIGURATION =================
// Motor A (Left Motor)
#define PIN_IN1 18
#define PIN_IN2 19

// Motor B (Right Motor)
#define PIN_IN3 21
#define PIN_IN4 22

// IR Edge Sensor (Digital input, e.g., TCRT5000)
#define PIN_EDGE_SENSOR 34
#define EDGE_ACTIVE_LEVEL LOW // LOW when detecting white border line

// Status / Debug LED
#define PIN_LED 2

// PWM Channels & Frequency for ESP32 LEDC
#define PWM_FREQ 20000
#define PWM_RES  8 // 8-bit resolution (0 - 255)
#define CH_IN1 0
#define CH_IN2 1
#define CH_IN3 2
#define CH_IN4 3

// ================= NETWORK & UDP =================
const char* AP_SSID = "SumoBot";
const char* AP_PASS = "12345678";
const int   UDP_PORT = 4210;

IPAddress local_IP(192, 168, 4, 1);
IPAddress gateway(192, 168, 4, 1);
IPAddress subnet(255, 255, 255, 0);

WiFiUDP udp;
WebServer webServer(80);

// ================= CONTROL & FAILSAFE STATE =================
uint8_t  lastSeq = 0;
uint32_t lastPacketTime = 0;
uint32_t validPacketCount = 0;

// Slew rate / Traction control current speeds
float currentLeftSpeed = 0.0f;
float currentRightSpeed = 0.0f;

// Autonomous maneuvers
uint8_t robotState = 0; // bit0: 180 turn, bit1: edge reverse
uint32_t maneuverEndTime = 0;
bool prevLeftTurnFlag = false;
bool prevRightTurnFlag = false;

// HTML page for Web OTA update
const char* serverIndex =
  "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>"
  "<title>SumoBot Wireless OTA</title>"
  "<style>"
  "body{background:#0B0F14;color:#E0E6ED;font-family:sans-serif;text-align:center;padding:20px;}"
  ".card{background:#18212B;border:2px solid #22AA77;border-radius:12px;max-width:400px;margin:auto;padding:24px;box-shadow:0 8px 24px rgba(0,0,0,0.5);}"
  "h1{color:#22AA77;font-size:22px;letter-spacing:1px;margin-bottom:8px;}"
  "p{color:#A0B0C0;font-size:14px;}"
  "input[type=file]{margin:20px 0;background:#0B0F14;padding:10px;border-radius:6px;border:1px solid #334455;color:#E0E6ED;width:90%;}"
  ".btn{background:#2277CC;color:white;border:none;padding:12px 28px;border-radius:24px;font-size:16px;font-weight:bold;cursor:pointer;}"
  ".btn:hover{background:#55AAFF;}"
  "</style></head><body>"
  "<div class='card'>"
  "<h1>SUMOBOT WIRELESS OTA</h1>"
  "<p>Upload new firmware without any USB cable.</p>"
  "<form method='POST' action='/update' enctype='multipart/form-data'>"
  "<input type='file' name='update' accept='.bin' required><br>"
  "<input type='submit' value='FLASH FIRMWARE' class='btn'>"
  "</form></div></body></html>";

// ================= MOTOR HELPER FUNCTIONS =================
void setMotorOutputs(int leftPWM, int rightPWM) {
  // Left Motor
  if (leftPWM > 0) {
    ledcWrite(CH_IN1, constrain(leftPWM, 0, 255));
    ledcWrite(CH_IN2, 0);
  } else if (leftPWM < 0) {
    ledcWrite(CH_IN1, 0);
    ledcWrite(CH_IN2, constrain(-leftPWM, 0, 255));
  } else {
    ledcWrite(CH_IN1, 0);
    ledcWrite(CH_IN2, 0);
  }

  // Right Motor
  if (rightPWM > 0) {
    ledcWrite(CH_IN3, constrain(rightPWM, 0, 255));
    ledcWrite(CH_IN4, 0);
  } else if (rightPWM < 0) {
    ledcWrite(CH_IN3, 0);
    ledcWrite(CH_IN4, constrain(-rightPWM, 0, 255));
  } else {
    ledcWrite(CH_IN3, 0);
    ledcWrite(CH_IN4, 0);
  }
}

void stopMotors() {
  currentLeftSpeed = 0.0f;
  currentRightSpeed = 0.0f;
  ledcWrite(CH_IN1, 0);
  ledcWrite(CH_IN2, 0);
  ledcWrite(CH_IN3, 0);
  ledcWrite(CH_IN4, 0);
}

// ================= WEB OTA SETUP =================
void setupWebOTA() {
  webServer.on("/", HTTP_GET, []() {
    webServer.send(200, "text/html", serverIndex);
  });
  webServer.on("/update", HTTP_GET, []() {
    webServer.send(200, "text/html", serverIndex);
  });
  webServer.on("/update", HTTP_POST, []() {
    webServer.sendHeader("Connection", "close");
    webServer.send(200, "text/plain", (Update.hasError()) ? "UPDATE FAILED!" : "UPDATE SUCCESSFUL! REBOOTING...");
    delay(500);
    ESP.restart();
  }, []() {
    HTTPUpload& upload = webServer.upload();
    if (upload.status == UPLOAD_FILE_START) {
      Serial.printf("OTA Update: %s\n", upload.filename.c_str());
      stopMotors();
      if (!Update.begin(UPDATE_SIZE_UNKNOWN)) {
        Update.printError(Serial);
      }
    } else if (upload.status == UPLOAD_FILE_WRITE) {
      if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) {
        Update.printError(Serial);
      }
    } else if (upload.status == UPLOAD_FILE_END) {
      if (Update.end(true)) {
        Serial.printf("OTA Update Success: %u bytes\nRebooting...\n", upload.totalSize);
      } else {
        Update.printError(Serial);
      }
    }
  });
  webServer.begin();
}

// ================= ARDUINO IDE OTA SETUP =================
void setupArduinoOTA() {
  ArduinoOTA.setHostname("SumoBot");
  ArduinoOTA.onStart([]() {
    stopMotors();
    Serial.println("ArduinoOTA: Starting wireless flashing...");
  });
  ArduinoOTA.onEnd([]() {
    Serial.println("\nArduinoOTA: Flashing complete! Restarting...");
  });
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    Serial.printf("OTA Progress: %u%%\r", (progress / (total / 100)));
  });
  ArduinoOTA.onError([](ota_error_t error) {
    Serial.printf("OTA Error[%u]: ", error);
  });
  ArduinoOTA.begin();
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== SumoBot ESP32 Initializing ===");

  // Pin Configuration
  pinMode(PIN_EDGE_SENSOR, INPUT_PULLUP);
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, LOW);

  // Configure Motor PWM channels
  ledcSetup(CH_IN1, PWM_FREQ, PWM_RES);
  ledcSetup(CH_IN2, PWM_FREQ, PWM_RES);
  ledcSetup(CH_IN3, PWM_FREQ, PWM_RES);
  ledcSetup(CH_IN4, PWM_FREQ, PWM_RES);

  ledcAttachPin(PIN_IN1, CH_IN1);
  ledcAttachPin(PIN_IN2, CH_IN2);
  ledcAttachPin(PIN_IN3, CH_IN3);
  ledcAttachPin(PIN_IN4, CH_IN4);
  stopMotors();

  // Configure Access Point
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(local_IP, gateway, subnet);
  WiFi.softAP(AP_SSID, AP_PASS);

  Serial.print("Access Point Started: ");
  Serial.println(AP_SSID);
  Serial.print("IP Address: ");
  Serial.println(WiFi.softAPIP());

  // Start UDP Listener
  udp.begin(UDP_PORT);
  Serial.printf("UDP Listening on port %d\n", UDP_PORT);

  // Initialize Wireless Flashing (OTA)
  setupArduinoOTA();
  setupWebOTA();
  Serial.println("OTA Wireless Uploads Ready: Network Port & http://192.168.4.1/update");

  digitalWrite(PIN_LED, HIGH);
}

// ================= MAIN LOOP =================
void loop() {
  // Handle background wireless OTA updates
  ArduinoOTA.handle();
  webServer.handleClient();

  uint32_t now = millis();

  // 1. Line Sensor Check
  bool edgeDetected = (digitalRead(PIN_EDGE_SENSOR) == EDGE_ACTIVE_LEVEL);

  // Automatic Edge Avoidance Maneuver
  if (edgeDetected && (robotState & 0x02) == 0 && (robotState & 0x01) == 0) {
    robotState |= 0x02; // Edge reverse active
    maneuverEndTime = now + 280; // Reverse for 280 ms
  }

  // Handle active maneuvers (180 Turn or Edge Reverse)
  if (robotState != 0) {
    if (now >= maneuverEndTime) {
      robotState = 0; // Maneuver completed
      stopMotors();
    } else {
      if ((robotState & 0x02) != 0) {
        // Edge reverse: Back up and pivot
        setMotorOutputs(-180, -220);
      } else if ((robotState & 0x01) != 0) {
        // 180 Quick pivot turn
        setMotorOutputs(-210, 210);
      }
    }
  }

  // 2. Process Incoming UDP Packets
  int packetSize = udp.parsePacket();
  if (packetSize >= 7) {
    uint8_t buffer[7];
    udp.read(buffer, 7);

    // Validate Header (0xA5)
    if (buffer[0] == 0xA5) {
      uint8_t seq      = buffer[1];
      int8_t  thr      = (int8_t)buffer[2];
      int8_t  steer    = (int8_t)buffer[3];
      uint8_t flags    = buffer[4];
      uint8_t maxSpeed = buffer[5];
      uint8_t receivedChecksum = buffer[6];

      // Validate Checksum: (b1 ^ b2 ^ b3 ^ b4 ^ b5 ^ 0x5A) & 0xFF
      uint8_t expectedChecksum = (seq ^ buffer[2] ^ buffer[3] ^ flags ^ maxSpeed ^ 0x5A) & 0xFF;

      if (receivedChecksum == expectedChecksum) {
        lastPacketTime = now;
        lastSeq = seq;
        validPacketCount++;

        bool leftTurnReq  = (flags & 0x01) != 0;
        bool rightTurnReq = (flags & 0x02) != 0;
        bool tractionOff  = (flags & 0x04) != 0;

        // Rising Edge Detection for 180 Turn
        if (robotState == 0) {
          if (leftTurnReq && !prevLeftTurnFlag) {
            robotState |= 0x01;
            maneuverEndTime = now + 320; // 320 ms 180 turn
            setMotorOutputs(-220, 220);
          } else if (rightTurnReq && !prevRightTurnFlag) {
            robotState |= 0x01;
            maneuverEndTime = now + 320;
            setMotorOutputs(220, -220);
          }
        }
        prevLeftTurnFlag = leftTurnReq;
        prevRightTurnFlag = rightTurnReq;

        // Drive Mixing if not in autonomous maneuver
        if (robotState == 0) {
          int leftMix  = thr + steer;
          int rightMix = thr - steer;

          int maxVal = max(abs(leftMix), abs(rightMix));
          if (maxVal > 100) {
            leftMix  = (leftMix * 100) / maxVal;
            rightMix = (rightMix * 100) / maxVal;
          }

          float targetLeft  = (leftMix * (float)maxSpeed) / 100.0f;
          float targetRight = (rightMix * (float)maxSpeed) / 100.0f;

          if (tractionOff) {
            // Direct instantaneous raw drive
            currentLeftSpeed  = targetLeft;
            currentRightSpeed = targetRight;
          } else {
            // Traction control: Slew-rate acceleration limiter
            float maxRamp = 18.0f; // max PWM change per 10 ms
            currentLeftSpeed  += constrain(targetLeft - currentLeftSpeed, -maxRamp, maxRamp);
            currentRightSpeed += constrain(targetRight - currentRightSpeed, -maxRamp, maxRamp);
          }

          setMotorOutputs((int)currentLeftSpeed, (int)currentRightSpeed);
        }

        // Send Telemetry Reply on every 5th valid packet (~20 Hz)
        if (validPacketCount % 5 == 0) {
          uint8_t reply[4];
          reply[0] = 0x5A;                         // Header
          reply[1] = seq;                          // Echoed sequence for ping
          reply[2] = edgeDetected ? 1 : 0;         // IR Sensor line state
          reply[3] = robotState & 0x03;            // bit0 = 180 turn, bit1 = edge reverse

          udp.beginPacket(udp.remoteIP(), udp.remotePort());
          udp.write(reply, 4);
          udp.endPacket();
        }
      }
    }
  }

  // 3. SAFETY FAILSAFE (200 ms timeout)
  if (now - lastPacketTime > 200) {
    if (robotState == 0) {
      stopMotors();
    }
  }
}
