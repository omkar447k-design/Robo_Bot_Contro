import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumobot_controller/protocol/packet.dart';

void main() {
  group('ControlPacket Protocol Tests (Section 2)', () {
    test('ControlPacket serialization produces exact 7 bytes with correct header', () {
      final packet = ControlPacket(
        seq: 1,
        thr: 50,
        steer: -50,
        flags: 0,
        maxSpeed: 255,
      );

      final bytes = packet.toBytes();
      expect(bytes.length, equals(7));
      expect(bytes[0], equals(0xA5)); // Header
      expect(bytes[1], equals(1)); // seq
      expect(bytes[2], equals(50)); // thr
      expect(bytes[3], equals((-50) & 0xFF)); // steer (-50 signed -> 206 uint8)
      expect(bytes[4], equals(0)); // flags
      expect(bytes[5], equals(255)); // maxSpeed

      final expectedChecksum =
          (bytes[1] ^ bytes[2] ^ bytes[3] ^ bytes[4] ^ bytes[5] ^ 0x5A) & 0xFF;
      expect(bytes[6], equals(expectedChecksum));
    });

    test('Negative throttle and steering are correctly encoded as signed int8 in uint8', () {
      final packet = ControlPacket(
        seq: 255,
        thr: -100,
        steer: -100,
        flags: 4, // TC off
        maxSpeed: 150,
      );

      final bytes = packet.toBytes();
      expect(bytes[0], equals(0xA5));
      expect(bytes[1], equals(255));
      expect(bytes[2], equals((-100) & 0xFF)); // 156
      expect(bytes[3], equals((-100) & 0xFF)); // 156
      expect(bytes[4], equals(4)); // bit 2 set
      expect(bytes[5], equals(150));

      final checksum =
          (255 ^ ((-100) & 0xFF) ^ ((-100) & 0xFF) ^ 4 ^ 150 ^ 0x5A) & 0xFF;
      expect(bytes[6], equals(checksum));
    });

    test('Max speed clamps between 80 and 255', () {
      final lowSpeed = ControlPacket(
        seq: 0,
        thr: 0,
        steer: 0,
        flags: 0,
        maxSpeed: 30, // should clamp to 80
      ).toBytes();
      expect(lowSpeed[5], equals(80));

      final highSpeed = ControlPacket(
        seq: 0,
        thr: 0,
        steer: 0,
        flags: 0,
        maxSpeed: 300, // should clamp to 255
      ).toBytes();
      expect(highSpeed[5], equals(255));
    });

    test('Checksum helper matches manual bitwise XOR with 0x5A', () {
      final b1 = 42;
      final b2 = 100;
      final b3 = 200;
      final b4 = 1;
      final b5 = 255;
      final cs = ControlPacket.computeChecksum(b1, b2, b3, b4, b5);
      expect(cs, equals((b1 ^ b2 ^ b3 ^ b4 ^ b5 ^ 0x5A) & 0xFF));
    });
  });

  group('TelemetryPacket Protocol Tests (Section 2)', () {
    test('Valid 4-byte packet parses correctly', () {
      // 0x5A, seq=10, edge=1, state=0b00000001 (doing 180 turn)
      final raw = Uint8List.fromList([0x5A, 10, 1, 1]);
      final telemetry = TelemetryPacket.tryParse(raw);

      expect(telemetry, isNotNull);
      expect(telemetry!.seq, equals(10));
      expect(telemetry.edge, isTrue);
      expect(telemetry.isTurning, isTrue);
      expect(telemetry.isEdgeReversing, isFalse);
      expect(telemetry.isTurnOrReverse, isTrue);
    });

    test('State bit 1 indicates edge reversing', () {
      final raw = Uint8List.fromList([0x5A, 25, 0, 2]); // bit 1 set
      final telemetry = TelemetryPacket.tryParse(raw);

      expect(telemetry, isNotNull);
      expect(telemetry!.edge, isFalse);
      expect(telemetry.isTurning, isFalse);
      expect(telemetry.isEdgeReversing, isTrue);
      expect(telemetry.isTurnOrReverse, isTrue);
    });

    test('Invalid header or length returns null', () {
      expect(TelemetryPacket.tryParse(Uint8List.fromList([0x00, 1, 0, 0])), isNull);
      expect(TelemetryPacket.tryParse(Uint8List.fromList([0x5A, 1, 0])), isNull);
      expect(TelemetryPacket.tryParse(Uint8List.fromList([0x5A, 1, 0, 0, 0])), isNull);
    });
  });
}
