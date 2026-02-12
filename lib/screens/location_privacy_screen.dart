import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class LocationPrivacyScreen extends StatelessWidget {
  const LocationPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Location Privacy")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_person, size: 64, color: Colors.blueGrey),
              const SizedBox(height: 24),
              Text(
                "Your Privacy Matters",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                AppConstants.privacyDisclaimer,
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 24),
              const Text(
                "How it works:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text("Location sharing is OFF by default."),
              ),
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text("Only activated when you trigger SOS."),
              ),
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text("Automatically stops when you mark yourself safe."),
              ),
            ],
        ),
      ),
    );
  }
}
