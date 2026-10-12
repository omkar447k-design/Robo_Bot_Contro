import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

import 'protocol/packet.dart';
import 'widgets/hold_button.dart';
import 'widgets/joystick.dart';

/// ControllerPage: Core Controller Screen (Sections 1-7, 10)
class ControllerPage extends StatefulWidget {
  final String initialBotIp;
  final int initialBotPort;

  const ControllerPage({
    super.key,
    this.initialBotIp = '192.168.4.1',
    this.initialBotPort = 4210,
  });

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage>
    with WidgetsBindingObserver {
  final Stopwatch _stopwatch = Stopwatch()..start();
  RawDatagramSocket? _socket;
  Timer? _sendTimer;
  Timer? _uiTimer;
  Timer? _rebindTimer;

  // Network targets
  late String _botIp;
  late int _botPort;
  InternetAddress? _botAddress;

  // Control state
  double _jx = 0.0;
  double _jy = 0.0;
  bool _leftHeld = false;
  bool _rightHeld = false;
  int _leftQueue = 0;
  int _rightQueue = 0;
  double _maxSpeed = 255.0;
  bool _tractionControlOn = true;

  // Telemetry & Ping state
  int _seq = 0;
  final List<int> _sentUs = List<int>.filled(256, 0);
  double _pingMs = -1.0;
  int _lastReplyMs = -100000;
  bool _edgeDetected = false;
  bool _robotBusy = false;

  final GlobalKey<JoystickState> _joystickKey = GlobalKey<JoystickState>();
  final GlobalKey<HoldButtonState> _leftButtonKey =
      GlobalKey<HoldButtonState>();
  final GlobalKey<HoldButtonState> _rightButtonKey =
      GlobalKey<HoldButtonState>();

  @override
  void initState() {
    super.initState();
    _botIp = widget.initialBotIp;
    _botPort = widget.initialBotPort;
    _resolveBotAddress();

    WidgetsBinding.instance.addObserver(this);
    _initSocket();

    // 100 Hz Send timer (every 10 ms)
    _sendTimer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => _sendControlPacket(),
    );

    // 5 Hz UI refresh timer (every 200 ms)
    _uiTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) {
        if (mounted) setState(() {});
      },
    );

    // Socket watchdog (retries binding every 2 seconds if socket is null)
    _rebindTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (_socket == null) {
          _initSocket();
        }
      },
    );
  }

  void _resolveBotAddress() {
    try {
      _botAddress = InternetAddress(_botIp);
    } catch (_) {
      _botAddress = null;
    }
  }

  Future<void> _initSocket() async {
    try {
      _socket?.close();
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket = socket;

      socket.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            _drainIncomingPackets();
          }
        },
        onError: (_) {
          _socket?.close();
          _socket = null;
        },
        onDone: () {
          _socket = null;
        },
        cancelOnError: false,
      );
    } catch (_) {
      _socket = null;
    }
  }

  void _drainIncomingPackets() {
    final socket = _socket;
    if (socket == null) return;

    while (true) {
      final datagram = socket.receive();
      if (datagram == null) break;

      final telemetry = TelemetryPacket.tryParse(datagram.data);
      if (telemetry != null) {
        final nowUs = _stopwatch.elapsedMicroseconds;
        final sendTime = _sentUs[telemetry.seq];
        final rttMs = (nowUs - sendTime) / 1000.0;

        if (rttMs >= 0 && rttMs < 2000) {
          _pingMs = _pingMs < 0 ? rttMs : (_pingMs * 0.7 + rttMs * 0.3);
        }

        _lastReplyMs = _stopwatch.elapsedMilliseconds;
        _edgeDetected = telemetry.edge;
        _robotBusy = telemetry.isTurnOrReverse;
      }
    }
  }

  void _sendControlPacket() {
    final socket = _socket;
    if (socket == null || _botAddress == null) return;

    // Joystick scaling: full range reached at 80% deflection
    final clampedX = (_jx / 0.8).clamp(-1.0, 1.0);
    final clampedY = (_jy / 0.8).clamp(-1.0, 1.0);
    final thr = (clampedY * 100).round();
    final steer = (clampedX * 100).round();

    // Button activation logic (guarantees at least 8 packets / 80ms per tap)
    final leftActive = _leftHeld || _leftQueue > 0;
    final rightActive = _rightHeld || _rightQueue > 0;
    if (_leftQueue > 0) _leftQueue--;
    if (_rightQueue > 0) _rightQueue--;

    // If both active, LEFT wins
    int flags = leftActive ? 1 : (rightActive ? 2 : 0);
    if (!_tractionControlOn) {
      flags |= 4; // bit2 = traction control OFF
    }

    _seq = (_seq + 1) & 0xFF;
    _sentUs[_seq] = _stopwatch.elapsedMicroseconds;

    final packet = ControlPacket(
      seq: _seq,
      thr: thr,
      steer: steer,
      flags: flags,
      maxSpeed: _maxSpeed.round(),
    );

    try {
      socket.send(packet.toBytes(), _botAddress!, _botPort);
    } catch (_) {
      // Never crash on network transport exceptions
    }
  }

  void _stopAllControls() {
    _jx = 0.0;
    _jy = 0.0;
    _leftHeld = false;
    _rightHeld = false;
    _leftQueue = 0;
    _rightQueue = 0;
    _joystickKey.currentState?.reset();
    _leftButtonKey.currentState?.reset();
    _rightButtonKey.currentState?.reset();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopAllControls();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sendTimer?.cancel();
    _uiTimer?.cancel();
    _rebindTimer?.cancel();
    _socket?.close();
    super.dispose();
  }

  Widget _buildStatusPill({
    required String text,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsPlaceholder() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                ListTile(
                  leading:
                      const Icon(Icons.wifi, color: Color(0xFF22AA77)),
                  title: const Text('Robot IP Address'),
                  subtitle: Text(_botIp),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.numbers, color: Color(0xFF22AA77)),
                  title: const Text('UDP Target Port'),
                  subtitle: Text('$_botPort'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Note: Configurable settings & persistence will be enabled in Section 8.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nowMs = _stopwatch.elapsedMilliseconds;
    final isConnected = (nowMs - _lastReplyMs) < 700;
    final isLongOffline = (nowMs - _lastReplyMs) > 3000;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              // ================= TOP BAR =================
              Row(
                children: [
                  const Text(
                    'SUMOBOT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 3.5,
                      color: Color(0xFFE0E6ED),
                    ),
                  ),
                  const Spacer(),
                  // Status Pill
                  _buildStatusPill(
                    text: isConnected
                        ? 'Connected  ${_pingMs < 0 ? '-' : _pingMs.toStringAsFixed(0)} ms'
                        : 'Offline',
                    color: isConnected
                        ? const Color(0xFF1A7F4B)
                        : const Color(0xFFB3261E),
                    icon: isConnected ? Icons.wifi : Icons.wifi_off,
                  ),
                  // Sensor Pill
                  _buildStatusPill(
                    text: _edgeDetected ? 'EDGE!' : 'Sensor OK',
                    color: _edgeDetected
                        ? const Color(0xFFC77D00)
                        : const Color(0xFF333B44),
                    icon: _edgeDetected
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline,
                  ),
                  // TURN Pill (visible only when robot is performing 180 or edge reverse)
                  if (_robotBusy)
                    _buildStatusPill(
                      text: 'TURN',
                      color: const Color(0xFF2277CC),
                      icon: Icons.sync,
                    ),
                  // Settings Button
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    tooltip: 'Settings',
                    onPressed: _showSettingsPlaceholder,
                  ),
                ],
              ),

              // ================= OFFLINE BANNER (Section 10) =================
              if (isLongOffline)
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x33B3261E),
                    border: Border.all(color: const Color(0xFFB3261E), width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: Color(0xFFFF6B6B)),
                      SizedBox(width: 6),
                      Text(
                        'Not connected to SumoBot WiFi. Connect to "SumoBot" AP (192.168.4.1).',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // ================= MAIN INTERFACE =================
              Expanded(
                child: Row(
                  children: [
                    // LEFT HALF: Virtual Joystick
                    Expanded(
                      child: Center(
                        child: Joystick(
                          key: _joystickKey,
                          onChanged: (x, y) {
                            _jx = x;
                            _jy = y;
                          },
                        ),
                      ),
                    ),

                    // RIGHT HALF: 180 Buttons + Speed Slider + Traction Control
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final buttonSize = min(
                            constraints.maxHeight * 0.36,
                            constraints.maxWidth * 0.40,
                          );

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Quick 180 Turn Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HoldButton(
                                    key: _leftButtonKey,
                                    label: '↺\nLEFT\n180°',
                                    size: buttonSize,
                                    onDown: () {
                                      _leftHeld = true;
                                      _leftQueue = 8;
                                    },
                                    onUp: () {
                                      _leftHeld = false;
                                    },
                                  ),
                                  const SizedBox(width: 20),
                                  HoldButton(
                                    key: _rightButtonKey,
                                    label: '↻\nRIGHT\n180°',
                                    size: buttonSize,
                                    onDown: () {
                                      _rightHeld = true;
                                      _rightQueue = 8;
                                    },
                                    onUp: () {
                                      _rightHeld = false;
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Speed Slider
                              Text(
                                'Speed ${_maxSpeed.round()}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC5D1DE),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFF22AA77),
                                  inactiveTrackColor: const Color(0xFF1E2833),
                                  thumbColor: const Color(0xFF22AA77),
                                  overlayColor: const Color(0x3322AA77),
                                  trackHeight: 4.0,
                                ),
                                child: Slider(
                                  min: 80,
                                  max: 255,
                                  value: _maxSpeed,
                                  onChanged: (val) {
                                    setState(() {
                                      _maxSpeed = val;
                                    });
                                  },
                                ),
                              ),

                              // Traction Control Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Traction control',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFC5D1DE),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Switch(
                                    value: _tractionControlOn,
                                    activeThumbColor: const Color(0xFF22AA77),
                                    onChanged: (val) {
                                      setState(() {
                                        _tractionControlOn = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
