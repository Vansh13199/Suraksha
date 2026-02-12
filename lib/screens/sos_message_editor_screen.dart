import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/primary_button.dart';

class SosMessageEditorScreen extends StatefulWidget {
  const SosMessageEditorScreen({super.key});

  @override
  State<SosMessageEditorScreen> createState() => _SosMessageEditorScreenState();
}

class _SosMessageEditorScreenState extends State<SosMessageEditorScreen> {
  final _controller = TextEditingController(text: AppConstants.sosMessageTemplate);

  void _saveMessage() {
    // Save to SharedPreferences
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Emergency message updated")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Emergency Message")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "This message will be sent to your emergency contacts along with your live location link.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter your custom SOS message...",
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(text: "Save Message", onPressed: _saveMessage),
          ],
        ),
      ),
    );
  }
}
