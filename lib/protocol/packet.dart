import 'dart:typed_data';

/// App -> Robot control packet definition (Section 2)
class ControlPacket {
  static const int header = 0xA5;

  final int seq;
  final int thr; // signed int8 (-100..100)
  final int steer; // signed int8 (-100..100)
  final int flags; // bit0: Left 180, bit1: Right 180, bit2: TC off
  final int maxSpeed; // uint8 (80..255)

  const ControlPacket({
    required this.seq,
    required this.thr,
    required this.steer,
    required this.flags,
    required this.maxSpeed,
  });

  /// Checksum formula: (b1 ^ b2 ^ b3 ^ b4 ^ b5 ^ 0x5A) & 0xFF
  static int computeChecksum(int b1, int b2, int b3, int b4, int b5) {
    return (b1 ^ b2 ^ b3 ^ b4 ^ b5 ^ 0x5A) & 0xFF;
  }

  /// Serializes the control packet to a 7-byte Uint8List.
  Uint8List toBytes() {
    final bytes = Uint8List(7);
    bytes[0] = header;
    bytes[1] = seq & 0xFF;
    bytes[2] = thr & 0xFF;
    bytes[3] = steer & 0xFF;
    bytes[4] = flags & 0xFF;
    bytes[5] = maxSpeed.clamp(80, 255) & 0xFF;
    bytes[6] = computeChecksum(
      bytes[1],
      bytes[2],
      bytes[3],
      bytes[4],
      bytes[5],
    );
    return bytes;
  }
}

/// Robot -> App telemetry packet definition (Section 2)
class TelemetryPacket {
  static const int header = 0x5A;

  final int seq;
  final bool edge;
  final int state;

  const TelemetryPacket({
    required this.seq,
    required this.edge,
    required this.state,
  });

  bool get isTurning => (state & 0x01) != 0;
  bool get isEdgeReversing => (state & 0x02) != 0;
  bool get isTurnOrReverse => (state & 0x03) != 0;

  /// Parses a 4-byte telemetry buffer. Returns null if invalid.
  static TelemetryPacket? tryParse(Uint8List bytes) {
    if (bytes.length != 4 || bytes[0] != header) {
      return null;
    }
    return TelemetryPacket(
      seq: bytes[1],
      edge: bytes[2] == 1,
      state: bytes[3],
    );
  }
}
