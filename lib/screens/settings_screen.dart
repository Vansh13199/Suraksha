import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'splash_screen.dart';
import 'location_privacy_screen.dart';

import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: AppTheme.primaryBlue),
              title: const Text("Profile"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
             const Divider(),
            ListTile(
              leading: const Icon(Icons.shield_outlined, color: AppTheme.primaryBlue),
              title: const Text("Privacy & Location"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPrivacyScreen()));
              },
            ),
             const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorRed),
              title: const Text("Logout"),
              onTap: () {
                 Provider.of<AuthProvider>(context, listen: false).signOut();
                 Navigator.pushAndRemoveUntil(
                   context, 
                   MaterialPageRoute(builder: (_) => const SplashScreen()),
                   (route) => false,
                 );
              },
            ),
          ],
        ),
      ),
    );
  }
}
