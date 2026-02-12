import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SosButton extends StatelessWidget {
  final VoidCallback onLongPress;
  final double size;

  const SosButton({
    super.key,
    required this.onLongPress,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.errorRed,
          boxShadow: [
            BoxShadow(
              color: AppTheme.errorRed.withOpacity(0.4),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sos, color: Colors.white, size: 64),
            const SizedBox(height: 8),
            Text(
              "HOLD 3 SEC",
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
