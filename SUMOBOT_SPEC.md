# SumoBot Controller Specification

A low-latency remote controller for an ESP32 sumo/soccer robot built with Flutter.

## 1. Network
- **Robot WiFi AP:** SSID `SumoBot`, password `12345678` (no internet).
- **Robot IP:** `192.168.4.1` (configurable).
- **Transport:** UDP, robot port `4210` (configurable).
- App binds one `RawDatagramSocket` on `InternetAddress.anyIPv4`, port `0`, and uses the same socket to send and receive.

## 2. Packets
### App -> Robot (7 bytes, sent every 10 ms / 100 Hz):
- `byte 0`: `0xA5` (header)
- `byte 1`: `seq` (0..255, wraps: `(seq + 1) & 0xFF`)
- `byte 2`: `thr` (signed int8 stored as uint8 `value & 0xFF`, -100..100)
- `byte 3`: `steer` (signed int8 stored as uint8, -100..100)
- `byte 4`: `flags`:
  - `bit0`: LEFT 180 turn active (1)
  - `bit1`: RIGHT 180 turn active (2)
  - `bit2`: Traction control OFF (1 = off, 0 = on)
  - (If both turn buttons are active, LEFT wins)
- `byte 5`: `maxSpeed` (uint8, 80..255)
- `byte 6`: `checksum` (`(b1 ^ b2 ^ b3 ^ b4 ^ b5 ^ 0x5A) & 0xFF`)

### Robot -> App (4 bytes, sent by robot on every 5th valid packet / ~20 Hz):
- `byte 0`: `0x5A` (header)
- `byte 1`: `seq` (echo of app's seq, used for ping)
- `byte 2`: `edge` (1 = IR sensor currently sees line, 0 = OK)
- `byte 3`: `state`:
  - `bit0`: robot is doing a 180 turn
  - `bit1`: robot is doing an edge reverse

## 3. Screen
- Single screen, landscape orientation (`DeviceOrientation.landscapeLeft`, `DeviceOrientation.landscapeRight`).
- Immersive sticky full-screen mode (`SystemUiMode.immersiveSticky`).
- Screen kept awake (`wakelock_plus`).
- Dark theme, background `#0B0F14`.

## 4. Joystick
- Custom multitouch widget via `Listener` tracking a single pointer ID.
- Pad: circle, fill `#18212B`, border 3px `#22AA77`.
- Knob: radius = `padSize * 0.17`, fill `#22AA77`.
- Center clamping to limit `lim = padSize/2 - knobRadius`.
- Deadzone threshold: 0.12.
- Scaling: full power reached at 80% deflection (`clamp(j / 0.8, -1.0, 1.0)`).

## 5. Quick 180 Turn Buttons
- `Listener` based instant response with haptic feedback.
- Hold + queue of 8 packets (80 ms minimum transmission) guarantees execution over lossy UDP.
