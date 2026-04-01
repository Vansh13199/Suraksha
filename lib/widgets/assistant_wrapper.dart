import 'package:flutter/material.dart';
import 'assistant_bubble.dart';
import 'assistant_chat_overlay.dart';

/// Wraps body content with the floating AI assistant bubble + chat overlay.
/// Usage: body: AssistantWrapper(child: YourBodyContent())
class AssistantWrapper extends StatelessWidget {
  final Widget child;

  const AssistantWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The actual body content — fills entire space
        Positioned.fill(child: child),

        // Chat overlay (above the content, below the bubble)
        const Positioned(
          bottom: 90,
          right: 16,
          child: AssistantChatOverlay(),
        ),

        // Floating bubble (bottom-right)
        const Positioned(
          bottom: 20,
          right: 16,
          child: AssistantBubble(),
        ),
      ],
    );
  }
}
