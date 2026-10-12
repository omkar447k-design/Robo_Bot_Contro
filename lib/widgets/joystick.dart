import 'dart:math';
import 'package:flutter/material.dart';

/// Custom virtual joystick widget (Section 4)
class Joystick extends StatefulWidget {
  final void Function(double x, double y) onChanged;
  final double deadzone;

  const Joystick({
    super.key,
    required this.onChanged,
    this.deadzone = 0.12,
  });

  @override
  State<Joystick> createState() => JoystickState();
}

class JoystickState extends State<Joystick> {
  Offset _normalizedOffset = Offset.zero;
  int? _activePointerId;

  void _updatePosition(Offset localPos, double padSize) {
    final center = Offset(padSize / 2, padSize / 2);
    final knobRadius = padSize * 0.17;
    final lim = padSize / 2 - knobRadius;

    var delta = localPos - center;
    final distance = delta.distance;
    if (distance > lim && distance > 0) {
      delta = delta * (lim / distance);
    }

    final norm = lim > 0 ? delta / lim : Offset.zero;

    setState(() {
      _normalizedOffset = norm;
    });

    if (norm.distance < widget.deadzone) {
      widget.onChanged(0.0, 0.0);
    } else {
      // Invert Y so up is positive
      widget.onChanged(norm.dx, -norm.dy);
    }
  }

  void _resetKnob() {
    _activePointerId = null;
    setState(() {
      _normalizedOffset = Offset.zero;
    });
    widget.onChanged(0.0, 0.0);
  }

  /// Exposed for testing or lifecycle reset
  void reset() => _resetKnob();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padSize = min(constraints.maxWidth, constraints.maxHeight) * 0.95;
        final knobRadius = padSize * 0.17;
        final lim = padSize / 2 - knobRadius;

        return SizedBox(
          width: padSize,
          height: padSize,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (_activePointerId == null) {
                _activePointerId = event.pointer;
                _updatePosition(event.localPosition, padSize);
              }
            },
            onPointerMove: (event) {
              if (event.pointer == _activePointerId) {
                _updatePosition(event.localPosition, padSize);
              }
            },
            onPointerUp: (event) {
              if (event.pointer == _activePointerId) {
                _resetKnob();
              }
            },
            onPointerCancel: (event) {
              if (event.pointer == _activePointerId) {
                _resetKnob();
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Joystick Base Pad
                Container(
                  width: padSize,
                  height: padSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF18212B),
                    border: Border.all(
                      color: const Color(0xFF22AA77),
                      width: 3.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3322AA77),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    // Subtle concentric deadzone guide
                    child: Container(
                      width: padSize * 0.24,
                      height: padSize * 0.24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x2222AA77),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // Joystick Movable Knob
                Positioned(
                  left: padSize / 2 + _normalizedOffset.dx * lim - knobRadius,
                  top: padSize / 2 + _normalizedOffset.dy * lim - knobRadius,
                  child: Container(
                    width: knobRadius * 2,
                    height: knobRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF22AA77),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Color(0x5522AA77),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
