import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sumobot_controller/controller_page.dart';
import 'package:sumobot_controller/widgets/joystick.dart';
import 'package:sumobot_controller/widgets/hold_button.dart';

void main() {
  testWidgets('ControllerPage smoke test', (WidgetTester tester) async {
    // Set typical landscape phone screen dimensions
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ControllerPage(),
      ),
    );
    await tester.pump();

    // Verify Title and Status Pills exist
    expect(find.text('SUMOBOT'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Sensor OK'), findsOneWidget);

    // Verify Core Widgets are in place
    expect(find.byType(Joystick), findsOneWidget);
    expect(find.byType(HoldButton), findsNWidgets(2));
    expect(find.text('Speed 255'), findsOneWidget);
    expect(find.text('Traction control'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    // Fast-forward periodic timers safely before tear down
    await tester.pump(const Duration(milliseconds: 300));
  });
}
