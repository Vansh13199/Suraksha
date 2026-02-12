import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/primary_button.dart';
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
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permissions are critical for safety features.")));
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.security, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              "We need your permission",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "To keep you safe, Suraksha+ needs access to:\n\n• Location: To share where you are during SOS.\n• Bluetooth: To connect with your ESP32 safety device.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const Spacer(),
            PrimaryButton(
              text: "Grant Permissions",
              onPressed: _requestPermissions,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _skipToHome,
              child: const Text("Skip for now"),
            ),
          ],
        ),
      ),
    );
  }
}
