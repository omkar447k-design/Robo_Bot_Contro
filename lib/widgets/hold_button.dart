import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Instant-response Hold Button widget for quick turns (Section 5)
class HoldButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final double size;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final bool enableHaptics;

  const HoldButton({
    super.key,
    required this.label,
    this.icon,
    required this.size,
    required this.onDown,
    required this.onUp,
    this.enableHaptics = true,
  });

  @override
  State<HoldButton> createState() => HoldButtonState();
}

class HoldButtonState extends State<HoldButton> {
  bool _isPressed = false;
  int? _pointerId;

  void _handleDown(int pointer) {
    if (_pointerId == null) {
      _pointerId = pointer;
      if (widget.enableHaptics) {
        HapticFeedback.mediumImpact();
      }
      setState(() => _isPressed = true);
      widget.onDown();
    }
  }

  void _handleUp(int pointer) {
    if (_pointerId == pointer) {
      _pointerId = null;
      setState(() => _isPressed = false);
      widget.onUp();
    }
  }

  /// Reset button state programmatically (e.g., on app lifecycle change)
  void reset() {
    if (_isPressed || _pointerId != null) {
      _pointerId = null;
      setState(() => _isPressed = false);
      widget.onUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalColor = const Color(0xFF2277CC);
    final pressedColor = const Color(0xFF55AAFF);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _handleDown(e.pointer),
      onPointerUp: (e) => _handleUp(e.pointer),
      onPointerCancel: (e) => _handleUp(e.pointer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed ? pressedColor : normalColor,
          boxShadow: [
            BoxShadow(
              color: _isPressed
                  ? const Color(0x6655AAFF)
                  : const Color(0x442277CC),
              blurRadius: _isPressed ? 14 : 8,
              spreadRadius: _isPressed ? 2 : 1,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.size * 0.32,
                  color: Colors.white,
                ),
                const SizedBox(height: 2),
              ],
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.size * 0.14,
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
