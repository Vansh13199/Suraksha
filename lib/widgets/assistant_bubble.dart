import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assistant_provider.dart';
import '../services/gemini_assistant_service.dart';
import '../core/theme/app_theme.dart';

/// Floating pill-shaped assistant button — port of ai-fab-pill from CSS
class AssistantBubble extends StatefulWidget {
  const AssistantBubble({super.key});

  @override
  State<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<AssistantBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AssistantProvider>(context);
    final isAlert = provider.currentState == SystemState.alert;

    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: provider.toggleChat,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          decoration: BoxDecoration(
            color: isAlert ? Colors.white : Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isAlert
                  ? AppTheme.alertRed.withOpacity(0.5)
                  : AppTheme.primaryBlue.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isAlert
                    ? AppTheme.alertRed.withOpacity(0.2)
                    : AppTheme.primaryBlue.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label
              Text(
                'Suraksha+ Assistant',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isAlert ? AppTheme.alertRed : AppTheme.textDark,
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              _buildAvatar(isAlert),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isAlert) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isAlert
                ? AppTheme.alertRed.withOpacity(0.3)
                : AppTheme.primaryBlue.withOpacity(0.15),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/assistant_avatar.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.primaryBlue,
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
