import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SosButton extends StatefulWidget {
  final VoidCallback onLongPress;
  final double size;

  const SosButton({
    super.key,
    required this.onLongPress,
    this.size = 200,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        // HapticFeedback.heavyImpact(); // Optional: Add haptic feedback if you want
        widget.onLongPress();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse Effect 1
          _buildPulseCircle(0.0),
          // Pulse Effect 2
          _buildPulseCircle(0.5),
          
          // Main Button
          Container(
            height: widget.size,
            width: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5252), Color(0xFFD50000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD50000).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sos_rounded, color: Colors.white, size: 72),
                const SizedBox(height: 8),
                Text(
                  "HOLD 3 SEC",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseCircle(double delay) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.5).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(delay, 1.0, curve: Curves.easeOut),
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.5, end: 0.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(delay, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: Container(
          height: widget.size,
          width: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF5252).withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
