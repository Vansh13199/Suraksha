import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart' hide AuthProvider;
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../providers/assistant_provider.dart';
import '../providers/sos_provider.dart';
import '../providers/auth_provider.dart';
import '../services/gemini_assistant_service.dart';
import '../services/auth_service.dart';
import 'in_app_live_location_screen.dart';

class EmergencyChatScreen extends StatefulWidget {
  final String? sessionId;
  const EmergencyChatScreen({super.key, this.sessionId});

  @override
  State<EmergencyChatScreen> createState() => _EmergencyChatScreenState();
}

class _EmergencyChatScreenState extends State<EmergencyChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _manualIdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _contactMessages = [];
  bool _isAiTyping = false;
  final GeminiAssistantService _geminiService = GeminiAssistantService();

  String? _activeSessionId;
  Map<String, dynamic>? _sessionData;
  bool _isLoadingSession = false;

  @override
  void initState() {
    super.initState();
    _activeSessionId = widget.sessionId;

    if (_activeSessionId != null && _activeSessionId!.isNotEmpty) {
      _fetchSessionDetails(_activeSessionId!);
    } else {
      _autoDiscoverActiveSession();
    }
  }

  /// Automatically look up any active SOS session where this user is an authorized contact
  Future<void> _autoDiscoverActiveSession() async {
    setState(() => _isLoadingSession = true);
    try {
      String? userPhone;
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        userPhone = auth.currentUser?.phoneNumber;
      } catch (_) {}

      if (userPhone == null || userPhone.trim().isEmpty) {
        userPhone = await AuthService().getUserPhone();
      }

      if (userPhone == null || userPhone.trim().isEmpty) {
        safePrint('[EmergencyChat] User phone not available for auto-discovery.');
        if (mounted) setState(() => _isLoadingSession = false);
        return;
      }

      final userDigits = userPhone.replaceAll(RegExp(r'\D'), '');
      final userLast10 = userDigits.length >= 10 ? userDigits.substring(userDigits.length - 10) : userDigits;

      const query = '''
        query ListSessions {
          listSOSSessions(limit: 50) {
            items {
              id phoneNumber isActive latitude longitude triggerType authorizedViewers createdAt
            }
          }
        }
      ''';
      final res = await Amplify.API.query(
        request: GraphQLRequest<String>(document: query),
      ).response;

      if (res.data != null) {
        final data = jsonDecode(res.data!);
        final items = List<Map<String, dynamic>>.from(data['listSOSSessions']['items'] ?? []);

        // Filter sessions where this user is an authorized viewer (and not their own SOS)
        final viewerSessions = items.where((s) {
          final viewers = List<String>.from(s['authorizedViewers'] ?? []);
          final senderDigits = (s['phoneNumber'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
          if (senderDigits.endsWith(userLast10)) return false;
          return viewers.any((v) => v.replaceAll(RegExp(r'\D'), '').endsWith(userLast10));
        }).toList();

        if (viewerSessions.isNotEmpty) {
          // Sort so newest session is first
          viewerSessions.sort((a, b) => (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));

          // Prioritize active session if any, otherwise newest
          final session = viewerSessions.firstWhere(
            (s) => s['isActive'] == true,
            orElse: () => viewerSessions.first,
          );

          safePrint('[EmergencyChat] Selected session: ${session['id']} from ${session['phoneNumber']} (active: ${session['isActive']})');
          if (mounted) {
            setState(() {
              _activeSessionId = session['id'];
              _sessionData = session;
              _isLoadingSession = false;
            });
            _enforceAlertMode();
            return;
          }
        }
      }
    } catch (e) {
      safePrint('[EmergencyChat] Error auto-discovering session: $e');
    }
    if (mounted) {
      setState(() => _isLoadingSession = false);
    }
  }

  /// Fetch full details for a known session ID
  Future<void> _fetchSessionDetails(String sessionId) async {
    setState(() => _isLoadingSession = true);
    _enforceAlertMode();
    try {
      final query = '''
        query GetSOSSession(\$id: ID!) {
          getSOSSession(id: \$id) {
            id phoneNumber isActive latitude longitude triggerType authorizedViewers createdAt
          }
        }
      ''';
      final res = await Amplify.API.query(
        request: GraphQLRequest<String>(document: query, variables: {'id': sessionId}),
      ).response;

      if (res.data != null) {
        final data = jsonDecode(res.data!);
        final session = data['getSOSSession'];
        if (session != null) {
          safePrint('[EmergencyChat] Loaded session details for ID: $sessionId');
          setState(() {
            _sessionData = Map<String, dynamic>.from(session);
          });
        }
      }
    } catch (e) {
      safePrint('[EmergencyChat] Error fetching session details: $e');
    }
    if (mounted) {
      setState(() => _isLoadingSession = false);
    }
  }

  void _enforceAlertMode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final assistantProvider = Provider.of<AssistantProvider>(context, listen: false);
        assistantProvider.setAlertStateForResponder();
      } catch (_) {}
    });
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

  Future<void> _launchTrackingUrl(String sessionId) async {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚀 Launching Live Tracking Dashboard...'),
        duration: Duration(seconds: 1),
      ),
    );

    final Uri url = Uri.https('suraksha.dev-vansh.in', '/', {'session': sessionId});
    try {
      safePrint('[EmergencyChat] Launching Tracking URL: $url');
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(url, mode: LaunchMode.platformDefault);
      }
      if (!launched) throw 'Could not launch browser';
    } catch (e) {
      safePrint('[EmergencyChat] Launch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open tracker: $e')),
        );
      }
    }
  }

  void _openInAppLiveMap(String sessionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppLiveLocationScreen(sessionId: sessionId),
      ),
    );
  }

  void _copyTrackingUrl(String sessionId) {
    final url = 'https://suraksha.dev-vansh.in/?session=$sessionId';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Live Tracking URL copied to clipboard!'),
        backgroundColor: AppTheme.successGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sosProvider = Provider.of<SosProvider>(context);

    // 🛡️ ROLE GUARD: If this device is the one with active SOS, redirect to SOS Active Screen
    if (sosProvider.isSosActive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("SOS Active"),
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
                "Restricted to Emergency Contacts",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Text(
                  "This screen is reserved for emergency contacts to track and assist you. Please use your SOS Control screen.",
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        title: Row(
          children: [
            const Text(
              "📢 Emergency Response",
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            if (_activeSessionId != null)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.alertRed.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.fiber_manual_record, color: AppTheme.alertRed, size: 10),
                    SizedBox(width: 4),
                    Text(
                      "LIVE SOS",
                      style: TextStyle(
                        color: AppTheme.alertRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingSession
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Checking for active emergency sessions..."),
                      ],
                    ),
                  )
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Active Emergency Card OR No Active Emergency Banner
                      if (_activeSessionId != null && _activeSessionId!.isNotEmpty) ...[
                        _buildActiveEmergencyCard(context),
                        const SizedBox(height: 16),
                        _buildSystemNotificationBubble(
                          context,
                          title: "🚨 Alert Received:",
                          content: "Emergency broadcast active from ${_sessionData?['phoneNumber'] ?? 'your contact'}. Streaming live GPS coordinates.",
                          timestamp: DateTime.now(),
                        ),
                        const SizedBox(height: 16),
                        ..._contactMessages.map((msg) => _buildConversationBubble(msg)),
                        if (_isAiTyping)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 8),
                            child: Text(
                              "Assistant is typing...",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ] else ...[
                        _buildNoActiveEmergencyCard(context),
                      ],
                    ],
                  ),
          ),
          
          // Input Area (Always available so contact can test or ask questions)
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
                          hintText: "Responder reply or note...",
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

  /// Card displayed when an SOS session is actively streaming
  Widget _buildActiveEmergencyCard(BuildContext context) {
    final senderPhone = _sessionData?['phoneNumber'] ?? 'Emergency Contact';
    final triggerType = _sessionData?['triggerType'] ?? 'MANUAL';
    final isActive = _sessionData?['isActive'] == true;
    final sessionId = _activeSessionId!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isActive ? AppTheme.alertRed : AppTheme.primaryBlue).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppTheme.alertRed : Colors.black12).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isActive ? AppTheme.alertRed : AppTheme.primaryBlue).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.warning_amber_rounded : Icons.history_rounded,
                  color: isActive ? AppTheme.alertRed : AppTheme.primaryBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive
                          ? (triggerType == 'LOW_BATTERY' ? "🔋 Low Battery Emergency (Active)" : "🚨 EMERGENCY SOS ACTIVE")
                          : "🛡️ Emergency Incident Record",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isActive ? AppTheme.alertRed : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "From: $senderPhone • ${isActive ? 'Broadcasting LIVE' : 'Session Completed'}",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.tag_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "Session: $sessionId",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryBlue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _copyTrackingUrl(sessionId),
                  tooltip: "Copy tracking link",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary Redirection Button: Web Tracker URL
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchTrackingUrl(sessionId),
              icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 20),
              label: const Text(
                "🌐 Redirect to Live Tracking Dashboard",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.alertRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Action: In-App Live Map
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openInAppLiveMap(sessionId),
              icon: const Icon(Icons.map_rounded, color: AppTheme.primaryBlue, size: 20),
              label: const Text(
                "🗺️ View In-App Live Map",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card displayed when no emergency session is currently incoming
  Widget _buildNoActiveEmergencyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: AppTheme.successGreen, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Active Emergencies",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            "None of your emergency contacts are currently broadcasting an SOS alert.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _autoDiscoverActiveSession,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Check for Active Alerts"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              side: const BorderSide(color: AppTheme.primaryBlue),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            "Or enter a Tracking Session ID manually:",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textGrey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualIdController,
                  decoration: InputDecoration(
                    hintText: "Paste Session ID...",
                    hintStyle: const TextStyle(fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final id = _manualIdController.text.trim();
                  if (id.isNotEmpty) {
                    setState(() {
                      _activeSessionId = id;
                    });
                    _fetchSessionDetails(id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text("Track"),
              ),
            ],
          ),
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
    final userName = authProvider.currentUser?.firstName ?? "Responder";
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
                  isUser ? userName : "Emergency Coordination Bot",
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
