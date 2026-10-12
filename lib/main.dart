import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'controller_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape orientations (Section 3)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Hide system bars (immersiveSticky mode)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Keep screen awake while controller is open (Section 3)
  try {
    await WakelockPlus.enable();
  } catch (_) {
    // Graceful fallback on unsupported platforms / mock tests
  }

  runApp(const SumoBotApp());
}

class SumoBotApp extends StatelessWidget {
  const SumoBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SumoBot Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF22AA77),
          secondary: Color(0xFF2277CC),
          surface: Color(0xFF141A22),
        ),
      ),
      home: const ControllerPage(),
    );
  }
}
