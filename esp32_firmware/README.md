# ESP32 SumoBot Firmware & Wireless (OTA) Flashing Guide

This directory contains the production-grade ESP32 firmware for the **SumoBot / Soccer Robot Controller**.

---

## 1. Hardware Pin Connections

| ESP32 Pin | Component Pin | Description |
|-----------|---------------|-------------|
| **GPIO 18** | Motor Driver IN1 | Left Motor Forward (PWM) |
| **GPIO 19** | Motor Driver IN2 | Left Motor Reverse (PWM) |
| **GPIO 21** | Motor Driver IN3 | Right Motor Forward (PWM) |
| **GPIO 22** | Motor Driver IN4 | Right Motor Reverse (PWM) |
| **GPIO 34** | IR Sensor DOUT | Digital Line / Border Sensor (TCRT5000) |
| **GPIO 2**  | Built-in LED | Status Indicator (ON when WiFi AP is ready) |
| **GND**     | Common GND | Shared GND between ESP32 and Motor Driver |

*Note: Compatible with standard motor drivers including L298N, TB6612FNG, DRV8833, and MX1508.*

---

## 2. Initial Setup (First Flash via USB)

1. Open `SumoBot_Firmware.ino` in the **Arduino IDE**.
2. Select your board: **Tools -> Board -> ESP32 Arduino -> ESP32 Dev Module**.
3. Plug your ESP32 board into your computer with a USB cable once for the initial firmware installation.
4. Select the COM port under **Tools -> Port**.
5. Click **Upload** (Arrow button).

Once uploaded, the ESP32 starts broadcasting the WiFi Access Point:
- **SSID:** `SumoBot`
- **Password:** `12345678`
- **Robot IP:** `192.168.4.1`

---

## 3. Wireless Firmware Uploads Without USB Cable (OTA)

You **never need a USB cable again** to flash updates or new features to the ESP32. You have two options:

### Method A: Arduino IDE Wireless OTA (Recommended for Developers)
1. Disconnect the USB cable from the ESP32. Power the ESP32 using the robot's battery.
2. On your laptop, connect to the WiFi network: **SumoBot** (Password: `12345678`).
3. In Arduino IDE, open **Tools -> Port**. Under **Network ports**, you will see:
   ```
   SumoBot at 192.168.4.1 (ESP32 Dev Module)
   ```
4. Select that network port and click **Upload**!
5. Arduino IDE will transmit and flash the code directly over WiFi.

### Method B: Web Browser OTA (Flash from Any Phone or Laptop)
1. In Arduino IDE, click **Sketch -> Export Compiled Binary** (or press `Ctrl + Alt + S`).
   - This creates a `.bin` file in the sketch folder (e.g., `SumoBot_Firmware.ino.esp32.bin`).
2. Connect your Phone or PC to the **SumoBot** WiFi network.
3. Open any web browser (Chrome, Edge, Safari) and navigate to:
   ```
   http://192.168.4.1/update
   ```
4. Click **Choose File**, select the `.bin` file, and press **FLASH FIRMWARE**.
5. The ESP32 flashes in seconds and automatically reboots with the new code!
