import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumobot_controller/widgets/hold_button.dart';
import 'package:sumobot_controller/widgets/joystick.dart';

void main() {
  group('Joystick Widget Tests (Section 4)', () {
    testWidgets('Joystick renders correctly and handles touch drag within limits', (tester) async {
      double lastX = -999;
      double lastY = -999;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: Joystick(
                  onChanged: (x, y) {
                    lastX = x;
                    lastY = y;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final joystickFinder = find.byType(Joystick);
      expect(joystickFinder, findsOneWidget);

      // Tap at the center - within deadzone (< 0.12)
      final center = tester.getCenter(joystickFinder);
      final gesture = await tester.startGesture(center);
      await tester.pump();
      expect(lastX, equals(0.0));
      expect(lastY, equals(0.0));

      // Move up significantly
      await gesture.moveTo(center + const Offset(0, -60));
      await tester.pump();
      expect(lastY, greaterThan(0.0)); // Inverted Y: moving up yields positive Y

      // Release gesture
      await gesture.up();
      await tester.pump();
      expect(lastX, equals(0.0));
      expect(lastY, equals(0.0));
    });
  });

  group('HoldButton Widget Tests (Section 5)', () {
    testWidgets('HoldButton triggers onDown on pointer press and onUp on release', (tester) async {
      bool downTriggered = false;
      bool upTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HoldButton(
                label: 'LEFT 180°',
                size: 80,
                enableHaptics: false,
                onDown: () => downTriggered = true,
                onUp: () => upTriggered = true,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.text('LEFT 180°');
      expect(buttonFinder, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump();
      expect(downTriggered, isTrue);
      expect(upTriggered, isFalse);

      await gesture.up();
      await tester.pump();
      expect(upTriggered, isTrue);
    });
  });
}
