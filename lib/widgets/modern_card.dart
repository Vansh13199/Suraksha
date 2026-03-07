import 'package:flutter/material.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double elevation;
  final Gradient? gradient;
  final Border? border;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    this.elevation = 4,
    this.gradient,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).cardColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          if (elevation > 0)
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.08 * elevation),
              offset: Offset(0, elevation * 2),
              blurRadius: elevation * 4,
              spreadRadius: 0,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
