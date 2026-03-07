import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/primary_button.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_card.dart';

class SosMessageEditorScreen extends StatefulWidget {
  const SosMessageEditorScreen({super.key});

  @override
  State<SosMessageEditorScreen> createState() => _SosMessageEditorScreenState();
}

class _SosMessageEditorScreenState extends State<SosMessageEditorScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: AppConstants.sosMessageTemplate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveMessage() {
    // Save to SharedPreferences logic would go here
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Emergency message updated"),
        backgroundColor: AppTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Message")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "This message will be sent to your emergency contacts along with your live location link.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ModernCard(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _controller,
                maxLines: 5,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Enter your custom SOS message...",
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "${_controller.text.length} chars",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textGrey),
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: "Save Message", 
              onPressed: _saveMessage,
            ),
          ],
        ),
      ),
    );
  }
}
