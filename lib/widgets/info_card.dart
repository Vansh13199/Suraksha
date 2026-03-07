import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'modern_card.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textGrey,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppTheme.textGrey),
        ],
      ),
    );
  }
}
