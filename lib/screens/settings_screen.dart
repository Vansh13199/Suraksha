import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/modes_provider.dart';
import '../../providers/assistant_provider.dart';
import '../../core/theme/app_theme.dart';
import 'splash_screen.dart';
import 'location_privacy_screen.dart';
import 'emergency_chat_screen.dart';
import 'esp32_gps_debug_screen.dart';

import 'profile_screen.dart';
import '../../widgets/modern_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ModernCard(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                children: [
                   _buildSettingsTile(
                     context,
                     icon: Icons.person_outline_rounded,
                     title: "Profile",
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                   ),
                   const Padding(
                     padding: EdgeInsets.symmetric(horizontal: 16),
                     child: Divider(height: 1),
                   ),
                   _buildSettingsTile(
                     context,
                     icon: Icons.shield_outlined,
                     title: "Privacy & Location",
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPrivacyScreen())),
                   ),
                   const Padding(
                     padding: EdgeInsets.symmetric(horizontal: 16),
                     child: Divider(height: 1),
                   ),
                   _buildSettingsTile(
                     context,
                     icon: Icons.bluetooth_connected,
                     title: "ESP32 GPS Debug",
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Esp32GpsDebugScreen())),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Consumer<ModesProvider>(
                builder: (context, modesProvider, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.directions_run_rounded, color: AppTheme.primaryBlue, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Activity Mode",
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.textDark),
                                ),
                                const Text(
                                  "Disables Auto-SOS HR triggers",
                                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: modesProvider.isActivityMode,
                            activeColor: AppTheme.primaryBlue,
                            onChanged: (value) {
                              modesProvider.setActivityMode(value);
                            },
                          ),
                        ],
                      ),
                      if (modesProvider.isActivityMode) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Timer Duration",
                              style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textDark),
                            ),
                            DropdownButton<int>(
                              value: modesProvider.selectedTimerMinutes,
                              underline: const SizedBox(),
                              items: List.generate(20, (index) => index + 1)
                                  .map((min) => DropdownMenuItem(
                                        value: min,
                                        child: Text("$min min"),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  modesProvider.setTimerMinutes(value);
                                  // Restart timer when newly selected if active
                                  modesProvider.setActivityMode(true);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Remaining Time:",
                              style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textDark),
                            ),
                            Text(
                              "${(modesProvider.remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(modesProvider.remainingSeconds % 60).toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ModernCard(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Text(
                      "AI Assistant Debug",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                    ),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.chat_bubble_outline_rounded,
                    title: "Open Emergency Chat",
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyChatScreen()));
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.battery_alert_rounded,
                    title: "Simulate Low Battery",
                    isDestructive: true,
                    onTap: () {
                      Provider.of<AssistantProvider>(context, listen: false).triggerLowBatteryAlert(15);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Simulated 15% battery. Check AI Assistant on home screen.")),
                      );
                      Navigator.pop(context); // Go back to Home
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.restore_rounded,
                    title: "Restore Normal State",
                    onTap: () {
                      Provider.of<AssistantProvider>(context, listen: false).restoreNormal(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Restored AI Assistant to NORMAL.")),
                      );
                      Navigator.pop(context); // Go back to Home
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.delete_outline_rounded,
                    title: "Clear Chat History",
                    isDestructive: true,
                    onTap: () {
                      Provider.of<AssistantProvider>(context, listen: false).clearHistory();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("AI Assistant history cleared.")),
                      );
                      Navigator.pop(context); // Go back to Home
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ModernCard(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: _buildSettingsTile(
                context,
                icon: Icons.logout_rounded,
                title: "Logout",
                isDestructive: true,
                onTap: () {
                   Provider.of<AuthProvider>(context, listen: false).signOut();
                   Navigator.pushAndRemoveUntil(
                     context, 
                     MaterialPageRoute(builder: (_) => const SplashScreen()),
                     (route) => false,
                   );
                },
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Version 1.0.0",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? AppTheme.alertRed.withOpacity(0.1) : AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isDestructive ? AppTheme.alertRed : AppTheme.primaryBlue, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? AppTheme.alertRed : AppTheme.textDark,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textGrey),
      onTap: onTap,
    );
  }
}
