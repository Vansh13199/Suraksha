import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:convert';
import '../../providers/ble_provider.dart';
import '../../providers/sos_provider.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/info_card.dart';
import '../../widgets/assistant_wrapper.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'sos_active_screen.dart';
import 'device_pairing_screen.dart';
import 'emergency_contacts_screen.dart';
import 'settings_screen.dart';
import 'location_privacy_screen.dart';
import 'in_app_live_location_screen.dart';
import 'emergency_chat_screen.dart'; // Add Chat screen import
import '../main.dart'; // Import to access pendingDeepLinkSessionId

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<Map<String, dynamic>> _incomingSessions = [];

  @override
  void initState() {
    super.initState();
    _checkIncomingSos();
    
    // 🛰️ DEEP LINK CONSUMPTION: Safely handle Cold Start routing *after* Splash completes
    if (pendingDeepLinkSessionId != null && pendingDeepLinkSessionId!.isNotEmpty) {
      final sessionIdToRoute = pendingDeepLinkSessionId!;
      pendingDeepLinkSessionId = null; // Clear to prevent loops
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        safePrint('[HomeDashboard] Consuming Cold Start ID: $sessionIdToRoute');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmergencyChatScreen(sessionId: sessionIdToRoute),
          ),
        );
      });
    }
  }

  Future<void> _checkIncomingSos() async {
    try {
      final userPhone = await AuthService().getUserPhone();
      if (userPhone == null) return;

      // Query all active SOS sessions and filter client-side for authorizedViewers
      final query = '''
        query ListSOS {
          listSOSSessions(filter: { isActive: { eq: true } }) {
            items {
              id phoneNumber isActive latitude longitude triggerType authorizedViewers
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
        final targeted = items.where((s) {
          final viewers = List<String>.from(s['authorizedViewers'] ?? []);
          return viewers.contains(userPhone) && s['phoneNumber'] != userPhone;
        }).toList();

        if (mounted) {
          setState(() => _incomingSessions = targeted);
        }
      }
    } catch (e) {
      safePrint('[Home] Failed to check incoming SOS: $e');
    }
  }

  void _onSosTriggered(BuildContext context) {
    Provider.of<SosProvider>(context, listen: false).handleAppTriggeredSos();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SosActiveScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final bleProvider = Provider.of<BleProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Suraksha+"),
        titleTextStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.textDark,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ),
        ],
      ),
      body: AssistantWrapper(
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.backgroundLight,
              const Color(0xFFE8F1FF),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 100),
          child: Column(
            children: [
              // ── Incoming SOS Banner ──
              if (_incomingSessions.isNotEmpty) ...[
                ..._incomingSessions.map((session) => _buildIncomingSosBanner(context, session)),
                const SizedBox(height: 16),
              ],

              // Status Section
              _buildStatusCard(context, bleProvider.isConnected),
              
              const SizedBox(height: 60),
              
              // SOS Button Area
              Column(
                children: [
                  Hero(
                    tag: 'sos_button',
                    child: SosButton(
                      onLongPress: () => _onSosTriggered(context),
                      size: 220,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "HOLD TO ALERT",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textGrey,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Press and hold for 3 seconds to send SOS",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textGrey.withOpacity(0.7),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // Quick Actions
              Text(
                "Quick Actions",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              InfoCard(
                title: "Emergency Contacts",
                content: "Manage trusted contacts",
                icon: Icons.contact_phone_rounded,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()));
                },
              ),
              const SizedBox(height: 16),
              InfoCard(
                title: "Location Privacy",
                content: "Location enabled only during SOS",
                icon: Icons.location_on_rounded,
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPrivacyScreen()));
                },
              ),
            ],
          ),
        ),
        ),  // Close Container
      ),  // Close AssistantWrapper
    );  // Close Scaffold
  }

  Widget _buildIncomingSosBanner(BuildContext context, Map<String, dynamic> session) {
    final triggerType = session['triggerType'] ?? 'MANUAL';
    final senderPhone = session['phoneNumber'] ?? 'Unknown';
    final sessionId = session['id'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InAppLiveLocationScreen(sessionId: sessionId),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF7043)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    triggerType == 'LOW_BATTERY'
                        ? "🔋 Low Battery Emergency!"
                        : "🚨 SOS Emergency!",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "From: $senderPhone — Tap to view live location",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isConnected ? AppTheme.successGreen.withOpacity(0.1) : AppTheme.alertRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? AppTheme.successGreen.withOpacity(0.3) : AppTheme.alertRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.successGreen : AppTheme.alertRed,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? "Device Connected" : "Device Disconnected",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  isConnected ? "Ready for SOS trigger" : "Tap to pair device",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textGrey,
                  ),
                ),
              ],
            ),
          ),
          if (!isConnected)
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DevicePairingScreen()));
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.alertRed,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text("PAIR"),
            ),
        ],
      ),
    );
  }
}
