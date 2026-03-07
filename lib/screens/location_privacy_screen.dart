import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_card.dart';

class LocationPrivacyScreen extends StatelessWidget {
  const LocationPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Location Privacy")),
      body: SingleChildScrollView( // Added scroll view for small screens
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, size: 64, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 24),
            Text(
              "Your Privacy Matches",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
             const SizedBox(height: 16),
            Text(
              AppConstants.privacyDisclaimer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "How it works:",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ModernCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.location_off_outlined, color: AppTheme.textGrey),
                    title: Text("Location sharing is OFF by default."),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.notification_important_outlined, color: AppTheme.alertRed),
                    title: Text("Only activated when you trigger SOS."),
                  ),
                   Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.check_circle_outline, color: AppTheme.successGreen),
                    title: Text("Automatically stops when you mark yourself safe."),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
