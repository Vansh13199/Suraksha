import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/primary_button.dart';
import '../../core/theme/app_theme.dart';
import 'device_pairing_screen.dart';
import 'home_dashboard_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _locationGranted = false;
  bool _bluetoothGranted = false;

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.sms, // For emergency contacts
    ].request();

    setState(() {
      _locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      _bluetoothGranted = (statuses[Permission.bluetooth]?.isGranted ?? false) || 
                          (statuses[Permission.bluetoothScan]?.isGranted ?? false);
    });

    if (_locationGranted && _bluetoothGranted) {
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const DevicePairingScreen()));
      }
    } else {
        // Allow to proceed even if not fully granted for demo, 
        // in real app block or show dialog
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text("Permissions are critical for safety features."),
               backgroundColor: AppTheme.alertRed,
             )
            );
        }
    }
  }

  void _skipToHome() {
     Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeDashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, size: 80, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 48),
              Text(
                "We need your permission",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "To keep you safe, Suraksha+ needs access to key device features:",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textGrey),
              ),
              const SizedBox(height: 32),
              _buildPermissionItem(
                context, 
                icon: Icons.location_on_outlined, 
                title: "Location", 
                description: "To share where you are during SOS."
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                context, 
                icon: Icons.bluetooth_connected, 
                title: "Bluetooth", 
                description: "To connect with your ESP32 safety device."
              ),
              const Spacer(),
              PrimaryButton(
                text: "Grant Permissions",
                onPressed: _requestPermissions,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _skipToHome,
                child: const Text("Skip for now", style: TextStyle(color: AppTheme.textGrey)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(BuildContext context, {required IconData icon, required String title, required String description}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.secondaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.secondaryBlue, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
            ],
          ),
        )
      ],
    );
  }
}
