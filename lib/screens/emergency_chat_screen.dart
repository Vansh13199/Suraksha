import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../providers/assistant_provider.dart';
import '../providers/sos_provider.dart';
import '../providers/auth_provider.dart';
import '../services/gemini_assistant_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'location_privacy_screen.dart';

class EmergencyChatScreen extends StatefulWidget {
  final String? sessionId;
  const EmergencyChatScreen({super.key, this.sessionId});

  @override
  State<EmergencyChatScreen> createState() => _EmergencyChatScreenState();
}

class _EmergencyChatScreenState extends State<EmergencyChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _contactMessages = [];
  bool _isAiTyping = false;
  final GeminiAssistantService _geminiService = GeminiAssistantService();

  @override
  void initState() {
    super.initState();
    
    // 🛰️ ALERT MODE ENFORCEMENT: If we arrived with a sessionId, force the UI into alert mode immediately
    if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final assistantProvider = Provider.of<AssistantProvider>(context, listen: false);
          assistantProvider.setAlertStateForResponder();
          print('[EmergencyChat] Responder Alert Mode Enforced for ID: ${widget.sessionId}');
        } catch (e) {
          print('[EmergencyChat] Error enforcing alert mode: $e');
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _contactMessages.add({'isUser': true, 'text': text, 'time': DateTime.now()});
      _isAiTyping = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final reply = await _geminiService.processContactAutoReply(text);
    if (!mounted) return;

    setState(() {
      _contactMessages.add({'isUser': false, 'text': reply, 'time': DateTime.now()});
      _isAiTyping = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    // We listen to the assistant provider to extract system/alert messages
    final provider = Provider.of<AssistantProvider>(context);
    final sosProvider = Provider.of<SosProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.currentUser?.firstName ?? "User";

    // 🛡️ ROLE GUARD: If this device is the sender, don't show the responder dashboard
    if (sosProvider.isSosActive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("SOS Dashboard Active"),
          backgroundColor: AppTheme.alertRed,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: AppTheme.alertRed),
              const SizedBox(height: 24),
              const Text(
                "Restricted to Responders",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Text(
                  "This coordination screen is reserved for your emergency contacts. Please use the SOS Active screen to manage your security status.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text("Return to Control Center"),
              )
            ],
          ),
        ),
      );
    }
    
    // Filter messages that represent the "Emergency Alerts" simulation
    final currentAlerts = provider.messages.where((m) => 
        m.isSystem || m.text.contains('critically low') || m.text.contains('battery')).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFFF8F9FA), // Light grey header matching AI_BOT
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        title: Row(
          children: [
            const Text(
              "📢 Emergency Contacts",
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "",
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Waiting status bubble
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50.withOpacity(0.5),
                        border: Border.all(color: Colors.red.shade100),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Waiting for system alerts...",
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Display actual alerts triggered by the system
                  if (provider.currentState == SystemState.alert) ...[
                    _buildAlertBubble(
                      context,
                      title: "🚨 EMERGENCY ALERT:",
                      content: "$userName's device is critically low on battery.",
                      showLocation: true,
                      timestamp: DateTime.now(),
                    ),
                    const SizedBox(height: 16),
                    _buildSystemNotificationBubble(
                      context,
                      title: "🚨 System Notification:",
                      content: "$userName → Battery Low Alert Sent",
                      timestamp: DateTime.now(),
                    ),
                    const SizedBox(height: 16),
                    ..._contactMessages.map((msg) => _buildConversationBubble(msg)),
                    if (_isAiTyping)
                       Padding(
                         padding: const EdgeInsets.only(top: 8, left: 8), 
                         child: Text("System is typing...", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic))
                       ),
                  ]
                ],
              ),
            ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Emergency contact reply...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBubble(BuildContext context, {required String title, required String content, required bool showLocation, required DateTime timestamp}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
          ),
          // 🛰️ VISUAL STATUS BANNER: Immediate feedback on ID status
          if (widget.sessionId == null || widget.sessionId!.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ID NOT FOUND! Please re-open the notification.',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          if (widget.sessionId != null && widget.sessionId!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tracking ID Active: ${widget.sessionId}',
                      style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(color: AppTheme.textDark, fontSize: 13),
          ),
          if (showLocation) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final sessionId = widget.sessionId;
                
                print('[EmergencyChat] Native Button Tapped. ID: $sessionId');
                
                if (sessionId != null && sessionId.isNotEmpty) {
                  // 🚀 PHYSICAL FEEDBACK: Make the device vibrate to confirm the tap
                  HapticFeedback.heavyImpact();

                  // 🚀 VISUAL FEEDBACK: Confirm the tap immediately
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🚀 Launching Tracking Dashboard...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }

                  final Uri url = Uri.https('suraksha.dev-vansh.in', '/', {'session': sessionId});
                  
                  try {
                    print('[EmergencyChat] Native Launch: $url');
                    bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
                    if (!launched) {
                      launched = await launchUrl(url, mode: LaunchMode.platformDefault);
                    }
                    if (!launched) throw 'All modes failed';
                  } catch (e) {
                    print('[EmergencyChat] LAUNCH ERROR: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open tracker: $e')),
                      );
                    }
                  }
                } else {
                  HapticFeedback.vibrate();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID Missing! Please re-open notification.')),
                  );
                }
              },
              icon: const Icon(Icons.location_on_rounded, color: AppTheme.primaryBlue, size: 20),
              label: const Text(
                "View Live Location",
                style: TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              DateFormat('h:mm a').format(timestamp),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSystemNotificationBubble(BuildContext context, {required String title, required String content, required DateTime timestamp}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(color: AppTheme.textDark, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              DateFormat('h:mm a').format(timestamp),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildConversationBubble(Map<String, dynamic> msg) {
    bool isUser = msg['isUser'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.currentUser?.firstName ?? "Me";
    final text = msg['text'] as String;
    final time = msg['time'] as DateTime;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          border: isUser ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: [
            if (!isUser) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person : Icons.support_agent_rounded,
                  size: 14,
                  color: isUser ? Colors.white70 : AppTheme.primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  isUser ? userName : "System Bot",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUser ? Colors.white70 : AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(color: isUser ? Colors.white : AppTheme.textDark, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('h:mm a').format(time),
              style: TextStyle(
                fontSize: 10,
                color: isUser ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
